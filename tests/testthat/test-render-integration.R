test_that("real rendering separates build failures from exercise behavior", {
  skip_if(Sys.getenv("TUTORIALVERSE_RENDER_TESTS") != "true",
          "Set TUTORIALVERSE_RENDER_TESTS=true to enable renderer integration checks.")
  skip_if_not_installed("callr")
  skip_if_not_installed("learnr")
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "Pandoc is required.")

  source <- make_render_source()
  on.exit(unlink(source$root, recursive = TRUE), add = TRUE)
  path <- file.path(source$root, source$file)
  header <- c("---", "title: Render boundary test", "output: learnr::tutorial",
              "runtime: shiny_prerendered", "---")
  setup <- c("```{r setup, include=FALSE}", "library(learnr)", "```")

  # Exercise code is deferred until a learner runs it. A successful build
  # therefore cannot establish that even this deliberately broken exercise works.
  writeLines(c(header, setup, "```{r broken, exercise=TRUE}",
               "stop('Intentional exercise failure')", "```"), path)
  report <- check_tutorial(check_record(), online = FALSE, render = TRUE,
                           tutorial_dir = source$root, tutorial_file = source$file)
  expect_identical(report$render$status, "pass", info = report$render$reason)
  expect_identical(report$execution$status, "unsupported")

  writeLines(c(header, setup, "```{r broken}",
               "stop('Intentional build failure')", "```"), path)
  result <- check_tutorial_render(learnr_adapter(), source$root, source$file, 120)
  expect_identical(result$status, "fail")
  expect_match(result$reason, "Intentional build failure", fixed = TRUE)
})
