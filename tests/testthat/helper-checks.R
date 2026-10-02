check_record <- function(engine = "learnr") {
  record <- read_tutorial_metadata(testthat::test_path("fixtures", "valid.yml"))$metadata
  record$engine <- engine
  record
}

check_statuses <- function(report) {
  fields <- c("metadata", "source", "lesson", "render", "execution", "accessibility")
  vapply(report[fields], function(check) check$status, character(1))
}

make_render_source <- function(engine = "learnr") {
  root <- tempfile("tutorialverse-test-")
  dir.create(root)
  file <- if (engine == "learnr") "tutorial.Rmd" else "tutorial.qmd"
  format <- if (engine == "learnr") "output: learnr::tutorial" else "format: live-html"
  writeLines(c("---", "title: Test tutorial", format, "---", "Test content."),
             file.path(root, file))
  list(root = root, file = file)
}
