test_that("offline reports never call the network or renderer", {
  testthat::local_mocked_bindings(
    fetch_tutorial_url = function(...) stop("Unexpected network access"),
    run_tutorial_renderer = function(...) stop("Unexpected rendering")
  )
  for (engine in c("learnr", "learnr2", "quarto-live")) {
    report <- check_tutorial(check_record(engine), online = FALSE)
    expect_s3_class(report, "tutorial_check_result")
    expect_identical(unname(check_statuses(report)),
                     c("pass", "not_run", "not_run", "not_run",
                       "unsupported", "unsupported"))
    expect_identical(report$adapter$engine, engine)
    expect_identical(report$id, "intro-example")
    expect_match(report$checked_at, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$")
    expect_true(nzchar(report$environment$R))
    expect_true(nzchar(report$environment$packages$curl))
    for (field in names(check_statuses(report))) {
      expect_true(nzchar(report[[field]]$reason))
    }
  }
})

test_that("paths, read results, and records share a report contract", {
  path <- testthat::test_path("fixtures", "valid.yml")
  parsed <- read_tutorial_metadata(path)
  reports <- lapply(list(path, parsed, parsed$metadata), check_tutorial, online = FALSE)
  expect_identical(reports[[1]]$metadata, reports[[2]]$metadata)
  expect_identical(reports[[2]]$metadata, reports[[3]]$metadata)
})

test_that("invalid metadata prevents URL and render work", {
  calls <- 0L
  testthat::local_mocked_bindings(
    fetch_tutorial_url = function(...) { calls <<- calls + 1L; stop("Unexpected request") },
    check_tutorial_render = function(...) { calls <<- calls + 1L; stop("Unexpected render") }
  )
  for (fixture in c("missing-metadata.yml", "malformed.yml", "duplicate-key.yml",
                    "invalid-engine.yml", "malformed-url.yml")) {
    report <- check_tutorial(testthat::test_path("fixtures", fixture), render = TRUE)
    expect_identical(report$metadata$status, "fail")
    expect_gt(nrow(report$metadata$issues), 0L)
    expect_identical(report$source$status, "not_run")
    expect_identical(report$lesson$status, "not_run")
    expect_identical(report$render$status, "not_run")
  }
  expect_identical(calls, 0L)
  unknown <- check_tutorial(testthat::test_path("fixtures", "invalid-engine.yml"))
  expect_null(unknown$adapter)
  expect_identical(unknown$execution$status, "not_run")
  malformed <- check_tutorial(testthat::test_path("fixtures", "malformed.yml"))
  expect_true(is.na(malformed$id))
  expect_true(is.na(malformed$engine))
})

test_that("duplicate ID context reaches metadata validation", {
  report <- check_tutorial(check_record(), online = FALSE,
                           existing_ids = "intro-example")
  expect_identical(report$metadata$issues$code, "duplicate_id")
  expect_identical(report$render$status, "not_run")
})

test_that("source and lesson failures are independent", {
  testthat::local_mocked_bindings(fetch_tutorial_url = function(url, method, timeout) {
    list(status_code = if (endsWith(url, "source")) 404L else 200L, url = url)
  })
  report <- check_tutorial(check_record())
  expect_identical(report$source$status, "fail")
  expect_identical(report$source$http_status, 404L)
  expect_identical(report$lesson$status, "pass")
  expect_identical(report$render$status, "not_run")
  expect_identical(report$execution$status, "unsupported")
})

test_that("renderer success never implies interactive or accessibility success", {
  testthat::local_mocked_bindings(
    check_tutorial_render = function(...) tutorial_check("pass", "Controlled render result.")
  )
  report <- check_tutorial(check_record(), online = FALSE, render = TRUE)
  expect_identical(report$render$status, "pass")
  expect_identical(report$execution$status, "unsupported")
  expect_identical(report$accessibility$status, "unsupported")
})

test_that("invalid controls fail clearly before checks run", {
  for (value in list(NULL, NA, 1, "TRUE", c(TRUE, FALSE), matrix(TRUE))) {
    expect_error(check_tutorial(check_record(), online = value), "online must")
    expect_error(check_tutorial(check_record(), render = value), "render must")
  }
  for (value in list(NULL, NA, 0, -1, Inf, "10", c(1, 2), matrix(1))) {
    expect_error(check_tutorial(check_record(), timeout = value), "timeout must")
    expect_error(check_tutorial(check_record(), render_timeout = value), "render_timeout must")
  }
})
