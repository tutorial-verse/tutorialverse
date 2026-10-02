check_tutorial_render <- function(adapter, tutorial_dir, tutorial_file, timeout) {
  if (is.null(tutorial_dir) || is.null(tutorial_file)) {
    return(tutorial_check(
      "not_run", "Rendering requires tutorial_dir and a relative tutorial_file."
    ))
  }
  if (!is_metadata_text(tutorial_dir) || !dir.exists(tutorial_dir) ||
      !is_metadata_text(tutorial_file) ||
      grepl("^(/|[A-Za-z]:|~)", tutorial_file)) {
    return(tutorial_check("fail", "Supply an existing directory and relative entry file."))
  }
  root <- normalizePath(tutorial_dir, winslash = "/", mustWork = TRUE)
  input <- file.path(root, tutorial_file)
  if (!file.exists(input) || dir.exists(input)) {
    return(tutorial_check("fail", "The tutorial entry file does not exist."))
  }
  input <- normalizePath(input, winslash = "/", mustWork = TRUE)
  if (!startsWith(input, paste0(root, "/"))) {
    return(tutorial_check("fail", "The tutorial entry file must remain inside tutorial_dir."))
  }
  format <- tryCatch(tutorial_source_format(input, adapter),
                     error = function(error) error)
  if (inherits(format, "error")) {
    return(tutorial_check("fail", conditionMessage(format)))
  }
  unavailable <- render_unavailable_reason(adapter)
  if (!is.null(unavailable)) {
    return(tutorial_check("not_run", unavailable))
  }

  workspace <- tempfile("tutorialverse-render-")
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  tryCatch({
    entries <- list.files(root, all.files = TRUE, no.. = TRUE)
    entries <- setdiff(entries, c(".git", ".Rproj.user"))
    copied <- file.copy(file.path(root, entries), workspace, recursive = TRUE)
    if (!all(copied)) stop("Could not copy all tutorial assets.", call. = FALSE)
    relative_input <- substring(input, nchar(root) + 2L)
    copied_input <- file.path(workspace, relative_input)

    # Remove this check's reserved output name only from the disposable copy.
    # Otherwise an old HTML file could make a renderer that wrote nothing pass.
    output_name <- "tutorialverse-check.html"
    stale <- list.files(workspace, pattern = "^tutorialverse-check[.]html$",
                        recursive = TRUE, full.names = TRUE, all.files = TRUE)
    unlink(stale)
    tools <- run_tutorial_renderer(adapter, copied_input, format, output_name,
                                   workspace, timeout)
    outputs <- list.files(workspace, pattern = "^tutorialverse-check[.]html$",
                          recursive = TRUE, full.names = TRUE, all.files = TRUE)
    if (length(outputs) != 1L || file.info(outputs)$size <= 0) {
      stop("The renderer did not produce exactly one nonempty HTML file.", call. = FALSE)
    }
    header <- readLines(outputs, n = 50L, warn = FALSE)
    if (!any(grepl("<!doctype html|<html([[:space:]>])", header, ignore.case = TRUE))) {
      stop("The render output does not contain an HTML document header.", call. = FALSE)
    }
    tutorial_check(
      "pass", "A fresh HTML document rendered; interactive behavior was not tested.",
      backend = adapter$render_backend, format = format,
      output_bytes = unname(file.info(outputs)$size), tools = tools
    )
  }, error = function(error) {
    status <- if (inherits(error, "callr_timeout_error")) "not_run" else "fail"
    tutorial_check(status, paste("Rendering did not complete:", conditionMessage(error)))
  })
}

tutorial_source_format <- function(input, adapter) {
  if (tolower(tools::file_ext(input)) != adapter$source_extension) {
    stop("The entry file extension does not match the selected engine.", call. = FALSE)
  }
  lines <- readLines(input, warn = FALSE, encoding = "UTF-8")
  if (length(lines) < 3L || trimws(lines[[1L]]) != "---") {
    stop("The entry file needs a YAML header declaring its output format.", call. = FALSE)
  }
  closing <- which(trimws(lines[-1L]) %in% c("---", "..."))
  if (length(closing) == 0L || closing[[1L]] < 2L) {
    stop("The entry file has no complete YAML header.", call. = FALSE)
  }
  header <- yaml::yaml.load(paste(lines[2L:closing[[1L]]], collapse = "\n"),
                            eval.expr = FALSE)
  if (nrow(metadata_mapping_issues(header)) > 0L) {
    stop("The tutorial YAML header must be a mapping.", call. = FALSE)
  }
  value <- header[[if (adapter$engine == "learnr") "output" else "format"]]
  formats <- if (is.character(value)) value else names(value)
  supported <- intersect(formats, adapter$source_formats)
  if (length(supported) == 0L) {
    stop("The document does not declare a supported format for this adapter.",
         call. = FALSE)
  }
  supported[[1L]]
}

render_unavailable_reason <- function(adapter) {
  installed <- vapply(adapter$render_packages, requireNamespace,
                       logical(1), quietly = TRUE)
  if (any(!installed)) {
    return(paste("Rendering requires these R packages:",
                 paste(adapter$render_packages[!installed], collapse = ", ")))
  }
  if (adapter$render_backend == "rmarkdown" && !rmarkdown::pandoc_available()) {
    return("Rendering requires Pandoc.")
  }
  if (adapter$render_backend == "quarto" && is.null(quarto::quarto_path())) {
    return("Rendering requires the Quarto executable.")
  }
  NULL
}

run_tutorial_renderer <- function(adapter, input, format, output_name,
                                 workspace, timeout) {
  # Rendering runs author code. A child process limits duration and keeps its
  # options, attached packages, and working directory out of the caller's R session.
  callr::r(
    function(engine, input, format, output_name) {
      if (engine == "learnr") {
        rmarkdown::render(input, output_format = format, output_file = output_name,
                          quiet = TRUE, envir = new.env(parent = globalenv()))
        return(list(pandoc = as.character(rmarkdown::pandoc_version())))
      }
      if (engine == "learnr2") {
        extension <- file.path(dirname(input), "_extensions", "r-wasm", "live")
        if (!dir.exists(extension)) {
          learnr2::add_live_extension(dirname(input), overwrite = FALSE)
        }
      }
      quarto::quarto_render(input, output_format = format, output_file = output_name,
                            quiet = TRUE, as_job = FALSE)
      list(quarto = as.character(quarto::quarto_version()))
    },
    args = list(engine = adapter$engine, input = input, format = format,
                output_name = output_name),
    libpath = .libPaths(), wd = workspace, timeout = timeout, user_profile = FALSE
  )
}
