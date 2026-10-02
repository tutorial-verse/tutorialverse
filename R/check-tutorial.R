#' Check tutorial metadata, URLs, and optional local rendering
#'
#' Produces separate results for metadata, source and lesson URL reachability,
#' rendering, interactive execution, and accessibility. There is no overall
#' passing status because incomplete checks must remain visible.
#'
#' @param path_or_record Path to a metadata YAML file, a named metadata list,
#'   or a result from [read_tutorial_metadata()].
#' @param online Whether to request the source and lesson URLs. Defaults to
#'   `TRUE`. `FALSE` skips these requests, but does not restrict network use by
#'   tutorial code when rendering is explicitly requested.
#' @param render Whether to render local tutorial source. Defaults to `FALSE`.
#'   Rendering executes author code. Supply only trusted local tutorials.
#' @param tutorial_dir Directory containing the tutorial and all local assets,
#'   project configuration, and extensions needed to render it.
#' @param tutorial_file Entry file, relative to `tutorial_dir`. It must resolve
#'   to a file inside that directory. No repository is cloned automatically.
#' @param timeout Positive number of seconds allowed per HTTP request.
#' @param render_timeout Positive number of seconds allowed for the render
#'   subprocess. Defaults to 120 seconds.
#' @param existing_ids IDs of other registry records, passed to
#'   [validate_tutorial_metadata()].
#' @return A named list of class `tutorial_check_result` containing `id`,
#'   `engine`, a UTC `checked_at` timestamp, the `adapter`, `environment`, and
#'   `metadata`, `source`, `lesson`, `render`, `execution`, and `accessibility`
#'   check results. Every result has a `status` and `reason`. Metadata also
#'   contains the original validation issues and record. URL results include
#'   the requested URL, HTTP status, final URL, and method when available.
#' @details
#' `pass` means the stated check completed successfully; `fail` means it found
#' a problem; `not_run` means it could not complete or was not requested;
#' `unsupported` means this prototype has no implementation for that check.
#'
#' Invalid metadata prevents URL requests and rendering. An unrecognized
#' engine leaves the adapter `NULL` and dependent checks `not_run`.
#'
#' URL checks follow up to five HTTP(S) redirects. HEAD is tried first, with a
#' streamed GET fallback only for HTTP 405 or 501. A final 2xx response passes.
#' HTTP 401, 403, 408, and 429 are inconclusive (`not_run`); other non-2xx
#' responses fail. Transport errors, including DNS failures and timeouts, are
#' `not_run`: they do not establish that a link is broken. HTTP success does
#' not prove repository identity, tutorial content, or interactive operation.
#'
#' Rendering copies the supplied directory into temporary storage, omitting
#' `.git` and `.Rproj.user`, and uses a separate R process with a time limit.
#' A matching document format and a newly produced, nonempty HTML file are
#' required to pass. Temporary output is removed afterward. This is process
#' isolation, not a security sandbox: tutorial code retains the user's access.
#' The learnr2 adapter adds its bundled Quarto Live extension to the copy only
#' when that extension is absent. The Quarto Live adapter requires the caller
#' to supply the extension and assets. Neither adapter runs browser exercises.
#'
#' Missing rendering dependencies, missing source arguments, and timeouts are
#' `not_run`. Invalid source paths, incompatible source formats, and renderer
#' errors are `fail`. See [learnr_adapter()] for supported source formats.
#' @export
#' @examples
#' record <- list(
#'   id = "intro-example", title = "Introduction", engine = "learnr",
#'   source = "https://example.org/source", lesson = "https://example.org/lesson",
#'   maintainer = "Example maintainer", license = "MIT", topics = "R"
#' )
#' report <- check_tutorial(record, online = FALSE)
#' report$metadata$status
#' report$render
check_tutorial <- function(path_or_record, online = TRUE, render = FALSE,
                           tutorial_dir = NULL, tutorial_file = NULL,
                           timeout = 10, render_timeout = 120,
                           existing_ids = character()) {
  check_flag(online, "online")
  check_flag(render, "render")
  check_timeout(timeout, "timeout")
  check_timeout(render_timeout, "render_timeout")

  input <- if (is.character(path_or_record)) {
    read_tutorial_metadata(path_or_record)
  } else {
    path_or_record
  }
  validation <- validate_tutorial_metadata(input, existing_ids = existing_ids)
  record <- validation$metadata
  # Invalid mappings cannot safely supply scalar report identifiers.
  field <- function(name) {
    if (nrow(metadata_mapping_issues(record)) == 0L &&
        is_metadata_text(record[[name]])) record[[name]] else NA_character_
  }
  adapter <- get_adapter(field("engine"))
  skipped <- tutorial_check("not_run", "Metadata must pass before this check runs.")
  report <- list(
    id = field("id"), engine = field("engine"),
    checked_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    adapter = adapter, environment = tutorial_environment(),
    metadata = c(
      tutorial_check(validation$status, if (validation$status == "pass") {
        "Required metadata satisfies the prototype contract."
      } else "Metadata contains validation issues."),
      list(issues = validation$issues, record = record)
    ),
    source = skipped, lesson = skipped, render = skipped,
    execution = tutorial_check("not_run", "No supported engine was selected."),
    accessibility = tutorial_check("not_run", "No supported engine was selected.")
  )
  if (!is.null(adapter)) {
    report$execution <- tutorial_check("unsupported", adapter$execution_reason)
    report$accessibility <- tutorial_check(
      "unsupported", "Automated accessibility checks are not implemented."
    )
  }
  if (validation$status == "pass") {
    report$source <- check_tutorial_url(record$source, online, timeout)
    report$lesson <- check_tutorial_url(record$lesson, online, timeout)
    report$render <- if (render) {
      check_tutorial_render(adapter, tutorial_dir, tutorial_file, render_timeout)
    } else {
      tutorial_check("not_run", "Rendering was not requested; use render = TRUE.")
    }
  }
  structure(report, class = c("tutorial_check_result", "list"))
}

tutorial_check <- function(status, reason, ...) {
  if (!status %in% c("pass", "fail", "not_run", "unsupported") ||
      !is_metadata_text(reason)) {
    stop("Invalid check status or reason.", call. = FALSE)
  }
  c(list(status = status, reason = reason), list(...))
}

check_flag <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value) ||
      !is.null(dim(value))) {
    stop(sprintf("%s must be TRUE or FALSE.", name), call. = FALSE)
  }
}

check_timeout <- function(value, name) {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
      value <= 0 || !is.null(dim(value))) {
    stop(sprintf("%s must be a positive, finite number of seconds.", name),
         call. = FALSE)
  }
}

tutorial_environment <- function() {
  packages <- c("tutorialverse", "yaml", "curl", "callr", "learnr",
                "learnr2", "rmarkdown", "quarto")
  versions <- vapply(packages, function(package) {
    tryCatch(as.character(utils::packageVersion(package)),
             error = function(error) NA_character_)
  }, character(1))
  list(R = as.character(getRversion()), platform = R.version$platform,
       packages = as.list(versions))
}
