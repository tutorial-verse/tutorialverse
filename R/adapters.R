#' Describe the checks implemented for a tutorial engine
#'
#' These adapters describe prototype capabilities, not installed dependencies.
#' Each supports metadata validation and opt-in HTML rendering of local sources.
#' Interactive execution and accessibility checks are not implemented.
#'
#' @return A named list containing the engine, logical capability flags, the
#'   render backend, source extension, supported document formats, required R
#'   packages for rendering, and the reason execution checks are unsupported.
#' @details
#' The learnr adapter supports `.Rmd` files using `learnr::tutorial`.
#' The learnr2 and Quarto Live adapters support `.qmd` files with `live-html`
#' or `live-revealjs` declared in the document's own YAML header. Inherited
#' formats and other output formats are outside this prototype's render scope.
#'
#' learnr2 uses Quarto Live, so their format checks overlap. A matching format
#' does not independently establish which authoring package produced a file.
#' [check_tutorial()] reports unavailable dependencies as `not_run` and never
#' installs packages or downloads tutorial source.
#' @export
#' @examples
#' learnr_adapter()
#' learnr2_adapter()
#' quarto_live_adapter()
learnr_adapter <- function() {
  tutorial_adapter(
    "learnr", "rmarkdown", "rmd", "learnr::tutorial",
    c("callr", "rmarkdown", "learnr"),
    "No Shiny session or interactive exercise assertions are implemented."
  )
}

#' @rdname learnr_adapter
#' @export
learnr2_adapter <- function() {
  tutorial_adapter(
    "learnr2", "quarto", "qmd", c("live-html", "live-revealjs"),
    c("callr", "quarto", "learnr2"),
    "No browser checks of WebR exercises, quizzes, or persistence are implemented."
  )
}

#' @rdname learnr_adapter
#' @export
quarto_live_adapter <- function() {
  tutorial_adapter(
    "quarto-live", "quarto", "qmd", c("live-html", "live-revealjs"),
    c("callr", "quarto"),
    "No browser checks of WebR or Pyodide exercises are implemented."
  )
}

tutorial_adapter <- function(engine, backend, extension, formats, packages,
                             execution_reason) {
  list(
    engine = engine,
    metadata_supported = TRUE,
    render_check_supported = TRUE,
    execution_check_supported = FALSE,
    accessibility_check_supported = FALSE,
    render_backend = backend,
    source_extension = extension,
    source_formats = formats,
    render_packages = packages,
    execution_reason = execution_reason
  )
}

get_adapter <- function(engine) {
  if (!is_metadata_text(engine)) {
    return(NULL)
  }
  switch(engine,
    learnr = learnr_adapter(),
    learnr2 = learnr2_adapter(),
    `quarto-live` = quarto_live_adapter(),
    NULL
  )
}
