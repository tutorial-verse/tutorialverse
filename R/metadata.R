#' Read tutorial metadata from YAML
#'
#' Reads one YAML mapping without evaluating R expressions. A passing read
#' indicates successful parsing only; use [validate_tutorial_metadata()] to
#' check the metadata contract. Read failures are returned as structured issues.
#'
#' @param path Path to a UTF-8 YAML file containing one tutorial record.
#' @return A named list with `status` (`"pass"` or `"fail"`), `metadata` (the
#'   parsed record, or `NULL` on failure), and `issues` (a data frame with
#'   character columns `field`, `code`, and `message`).
#' @export
#' @examples
#' path <- tempfile(fileext = ".yml")
#' writeLines("id: example", path)
#' result <- read_tutorial_metadata(path)
#' result$status
#' unlink(path)
read_tutorial_metadata <- function(path) {
  if (!is_metadata_text(path)) {
    return(metadata_result(issues = metadata_issue(
      "path", "invalid_path", "Supply one nonempty file path."
    )))
  }
  if (!file.exists(path) || dir.exists(path)) {
    return(metadata_result(issues = metadata_issue(
      "path", "unreadable_file", "The metadata file does not exist or is a directory."
    )))
  }

  # Parsing and I/O failures stay in the report so a registry can report all
  # records instead of stopping at the first broken file.
  parsed <- tryCatch(
    list(metadata = yaml::read_yaml(
      path, fileEncoding = "UTF-8", readLines.warn = FALSE, eval.expr = FALSE
    )),
    error = function(error) list(problem = conditionMessage(error)),
    warning = function(warning) list(problem = conditionMessage(warning))
  )
  if (!is.null(parsed$problem)) {
    return(metadata_result(issues = metadata_issue(
      "metadata", "read_error", parsed$problem
    )))
  }

  issues <- metadata_mapping_issues(parsed$metadata)
  metadata_result(parsed$metadata, issues)
}

#' Validate the common tutorial metadata contract
#'
#' Checks required fields, their types, supported engines, tutorial identifiers,
#' and HTTP(S) URL syntax. Does not perform network requests, execute tutorials,
#' or verify factual accuracy, license permissions, or maintainer identity.
#'
#' @param metadata A named list describing one tutorial, or the result of
#'   [read_tutorial_metadata()].
#' @param existing_ids Character vector of IDs belonging to other records in
#'   the registry. Exclude the current record. Defaults to no other IDs.
#' @return A named list with `status` (`"pass"` or `"fail"`), the unchanged
#'   `metadata`, and an `issues` data frame with character columns `field`,
#'   `code`, and `message`. All detected field issues are returned together.
#' @details
#' Required scalar text fields are `id`, `title`, `engine`, `source`, `lesson`,
#' `maintainer`, and `license`. `topics` must be a nonempty, unnamed sequence
#' of nonempty strings. Character vectors are also accepted for R callers.
#'
#' IDs contain lowercase ASCII letters or digits, with single hyphens between
#' groups. Engines are `learnr`, `learnr2`, or `quarto-live`.
#'
#' URLs use HTTP(S), an ASCII DNS hostname or IPv4 address, and an optional
#' port from 1 to 65535. Localhost is accepted. Credentials, IPv6 literals,
#' unencoded whitespace, and malformed percent escapes are outside this
#' prototype's URL contract. International hostnames must use ASCII encoding.
#'
#' Optional and additional fields are preserved without validation. Missing
#' values are never inferred or replaced. Duplicate YAML keys fail during
#' reading; duplicate names in R lists fail during validation.
#' @export
#' @examples
#' metadata <- list(
#'   id = "intro-example", title = "Introduction", engine = "learnr",
#'   source = "https://example.org/source",
#'   lesson = "https://example.org/lesson",
#'   maintainer = "Example maintainer", license = "MIT",
#'   topics = c("R", "data frames")
#' )
#' validate_tutorial_metadata(metadata)
#' validate_tutorial_metadata(metadata, existing_ids = "intro-example")
validate_tutorial_metadata <- function(metadata, existing_ids = character()) {
  if (inherits(metadata, "tutorial_metadata_result")) {
    if (identical(metadata$status, "fail")) {
      return(metadata)
    }
    metadata <- metadata$metadata
  }

  issues <- metadata_mapping_issues(metadata)
  if (nrow(issues) > 0L) {
    return(metadata_result(metadata, issues))
  }
  if (!is.character(existing_ids) || anyNA(existing_ids) ||
      !is.null(dim(existing_ids)) || any(!nzchar(trimws(existing_ids)))) {
    issues <- rbind(issues, metadata_issue(
      "existing_ids", "invalid_context",
      "Supply a character vector of nonempty IDs from other records."
    ))
  }

  required <- c(
    "id", "title", "engine", "source", "lesson", "maintainer", "license", "topics"
  )
  for (field in required) {
    value <- metadata[[field]]
    if (is.null(value)) {
      issues <- rbind(issues, metadata_issue(
        field, "missing_field", "A required field is absent or null."
      ))
    } else if (field == "topics") {
      if (!is_metadata_topics(value)) {
        issues <- rbind(issues, metadata_issue(
          field, "invalid_type", "Topics must be a nonempty sequence of strings."
        ))
      }
    } else if (!is_metadata_text(value)) {
      issues <- rbind(issues, metadata_issue(
        field, "invalid_type", "Expected one nonempty string."
      ))
    }
  }

  id <- metadata[["id"]]
  if (is_metadata_text(id)) {
    if (!grepl("^[a-z0-9]+(-[a-z0-9]+)*$", id)) {
      issues <- rbind(issues, metadata_issue(
        "id", "invalid_id", "Use lowercase letters or digits separated by hyphens."
      ))
    }
    if (is.character(existing_ids) && id %in% existing_ids) {
      issues <- rbind(issues, metadata_issue(
        "id", "duplicate_id", "Another record has the same tutorial ID."
      ))
    }
  }

  engine <- metadata[["engine"]]
  if (is_metadata_text(engine) &&
      !engine %in% c("learnr", "learnr2", "quarto-live")) {
    issues <- rbind(issues, metadata_issue(
      "engine", "unsupported_engine", "Use learnr, learnr2, or quarto-live."
    ))
  }
  for (field in c("source", "lesson")) {
    value <- metadata[[field]]
    if (is_metadata_text(value) && !is_metadata_url(value)) {
      issues <- rbind(issues, metadata_issue(
        field, "invalid_url", "Expected an HTTP(S) URL within the documented contract."
      ))
    }
  }
  metadata_result(metadata, issues)
}

metadata_result <- function(metadata = NULL, issues = metadata_issue()) {
  structure(
    list(
      status = if (nrow(issues) == 0L) "pass" else "fail",
      metadata = metadata,
      issues = issues
    ),
    class = c("tutorial_metadata_result", "list")
  )
}

metadata_issue <- function(field = character(), code = character(),
                           message = character()) {
  data.frame(field = field, code = code, message = message, stringsAsFactors = FALSE)
}

metadata_mapping_issues <- function(metadata) {
  if (!is.list(metadata) || is.data.frame(metadata) ||
      !is.null(dim(metadata)) || is.null(names(metadata)) ||
      anyNA(names(metadata)) || any(!nzchar(trimws(names(metadata))))) {
    return(metadata_issue(
      "metadata", "invalid_mapping", "Expected one YAML mapping or named R list."
    ))
  }
  if (anyDuplicated(names(metadata))) {
    return(metadata_issue(
      "metadata", "duplicate_key", "Metadata field names must be unique."
    ))
  }
  metadata_issue()
}

is_metadata_text <- function(value) {
  is.character(value) && length(value) == 1L && is.null(dim(value)) &&
    !is.na(value) && nzchar(trimws(value))
}

is_metadata_topics <- function(value) {
  (is.character(value) || is.list(value)) && length(value) > 0L &&
    is.null(names(value)) && is.null(dim(value)) &&
    all(vapply(value, is_metadata_text, logical(1)))
}

is_metadata_url <- function(value) {
  # Keep syntax checks independent of network availability. This deliberately
  # bounded grammar avoids treating a successful connection as valid metadata.
  if (grepl("[^!-~]", value) || grepl("[<>\"{}|\\\\^`]", value) ||
      grepl("%(?![0-9A-Fa-f]{2})", value, perl = TRUE)) {
    return(FALSE)
  }
  match <- regexec(
    "^https?://([^/?#:]+)(:([0-9]+))?([/?#].*)?$", value,
    ignore.case = TRUE
  )
  parts <- regmatches(value, match)[[1L]]
  if (length(parts) == 0L) {
    return(FALSE)
  }
  host <- parts[[2L]]
  port <- parts[[4L]]
  if (nzchar(port) && (nchar(port) > 5L ||
      as.integer(port) < 1L || as.integer(port) > 65535L)) {
    return(FALSE)
  }
  if (nchar(host) > 253L || startsWith(host, ".") || endsWith(host, ".")) {
    return(FALSE)
  }
  labels <- strsplit(host, ".", fixed = TRUE)[[1L]]
  if (any(!grepl("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$", labels)) ||
      any(nchar(labels) > 63L)) {
    return(FALSE)
  }
  if (grepl("^[0-9.]+$", host)) {
    # Numeric hosts must be unambiguous dotted IPv4, not shortened addresses.
    return(length(labels) == 4L &&
      all(grepl("^(0|[1-9][0-9]{0,2})$", labels)) &&
      all(as.numeric(labels) <= 255))
  }
  TRUE
}
