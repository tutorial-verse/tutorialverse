test_that("rendering needs explicit source arguments", {
  expect_identical(check_tutorial_render(learnr_adapter(), NULL, NULL, 1)$status, "not_run")
  expect_identical(check_tutorial_render(learnr_adapter(), "absent", "a.Rmd", 1)$status, "fail")
})

test_that("renderers operate on copies and produce fresh HTML", {
  for (engine in c("learnr", "learnr2", "quarto-live")) {
    source <- make_render_source(engine)
    on.exit(unlink(source$root, recursive = TRUE), add = TRUE)
    before <- readLines(file.path(source$root, source$file))
    workspace_used <- NULL
    testthat::local_mocked_bindings(
      render_unavailable_reason = function(adapter) NULL,
      run_tutorial_renderer = function(adapter, input, format, output_name, workspace, timeout) {
        workspace_used <<- workspace
        expect_false(startsWith(input, source$root))
        expect_identical(readLines(input), before)
        expect_identical(adapter$engine, engine)
        expect_identical(timeout, 3)
        writeLines(c("<!DOCTYPE html>", "<html>Rendered</html>"),
                   file.path(workspace, output_name))
        list(renderer = "controlled test")
      }
    )
    result <- check_tutorial_render(get_adapter(engine), source$root, source$file, 3)
    expect_identical(result$status, "pass")
    expect_gt(result$output_bytes, 0)
    expect_false(dir.exists(workspace_used))
    expect_identical(readLines(file.path(source$root, source$file)), before)
    expect_identical(list.files(source$root), source$file)
  }
})

test_that("stale files and fake HTML cannot make rendering pass", {
  source <- make_render_source()
  on.exit(unlink(source$root, recursive = TRUE), add = TRUE)
  writeLines("<html>Old output</html>", file.path(source$root, "tutorialverse-check.html"))
  for (output in list(NULL, character(), "plain text")) {
    testthat::local_mocked_bindings(
      render_unavailable_reason = function(adapter) NULL,
      run_tutorial_renderer = function(adapter, input, format, output_name, workspace, timeout) {
        expect_false(file.exists(file.path(workspace, output_name)))
        if (!is.null(output)) writeLines(output, file.path(workspace, output_name))
        list()
      }
    )
    expect_identical(
      check_tutorial_render(learnr_adapter(), source$root, source$file, 1)$status, "fail"
    )
  }
  expect_true(file.exists(file.path(source$root, "tutorialverse-check.html")))
})

test_that("missing dependencies and timeouts remain distinct from render errors", {
  source <- make_render_source()
  on.exit(unlink(source$root, recursive = TRUE), add = TRUE)
  testthat::local_mocked_bindings(
    render_unavailable_reason = function(adapter) "Rendering requires Pandoc."
  )
  result <- check_tutorial_render(learnr_adapter(), source$root, source$file, 1)
  expect_identical(result$status, "not_run")
  expect_match(result$reason, "Pandoc")

  testthat::local_mocked_bindings(
    render_unavailable_reason = function(adapter) NULL,
    run_tutorial_renderer = function(...) stop("Exercise setup failed.")
  )
  result <- check_tutorial_render(learnr_adapter(), source$root, source$file, 1)
  expect_identical(result$status, "fail")
  expect_match(result$reason, "Exercise setup failed", fixed = TRUE)

  testthat::local_mocked_bindings(run_tutorial_renderer = function(...) {
    stop(structure(list(message = "Render timed out", call = NULL),
                   class = c("callr_timeout_error", "error", "condition")))
  })
  result <- check_tutorial_render(learnr_adapter(), source$root, source$file, 1)
  expect_identical(result$status, "not_run")
  expect_match(result$reason, "timed out")
})

test_that("invalid entry files fail before running a renderer", {
  source <- make_render_source()
  on.exit(unlink(source$root, recursive = TRUE), add = TRUE)
  calls <- 0L
  testthat::local_mocked_bindings(run_tutorial_renderer = function(...) {
    calls <<- calls + 1L
  })
  expect_identical(check_tutorial_render(learnr_adapter(), source$root, "missing.Rmd", 1)$status, "fail")
  expect_identical(check_tutorial_render(learnr2_adapter(), source$root, source$file, 1)$status, "fail")
  absolute <- file.path(source$root, source$file)
  expect_identical(check_tutorial_render(learnr_adapter(), source$root, absolute, 1)$status, "fail")
  outside <- tempfile(fileext = ".Rmd")
  on.exit(unlink(outside), add = TRUE)
  file.copy(absolute, outside)
  result <- check_tutorial_render(learnr_adapter(), source$root,
                                  file.path("..", basename(outside)), 1)
  expect_identical(result$status, "fail")
  expect_match(result$reason, "inside")
  for (content in list("No header", c("---", "output: ["),
                       c("---", "output: html_document", "---"),
                       c("---", "output: [", "---"))) {
    writeLines(content, absolute)
    expect_identical(check_tutorial_render(learnr_adapter(), source$root, source$file, 1)$status, "fail")
  }
  expect_identical(calls, 0L)
})

test_that("named format options are preserved during format selection", {
  source <- make_render_source("quarto-live")
  on.exit(unlink(source$root, recursive = TRUE), add = TRUE)
  path <- file.path(source$root, source$file)
  writeLines(c("---", "format:", "  live-html:", "    toc: true", "---"), path)
  expect_identical(tutorial_source_format(path, quarto_live_adapter()), "live-html")
})
