test_that("HTTP response classes have honest statuses", {
  cases <- c(`200` = "pass", `204` = "pass", `206` = "pass",
             `301` = "fail", `401` = "not_run", `403` = "not_run",
             `404` = "fail", `408` = "not_run", `410` = "fail",
             `429` = "not_run", `500` = "fail", `503` = "fail")
  for (code in names(cases)) {
    testthat::local_mocked_bindings(fetch_tutorial_url = function(url, method, timeout) {
      expect_identical(timeout, 2)
      list(status_code = as.integer(code), url = "https://example.org/final")
    })
    result <- check_tutorial_url("https://example.org", TRUE, 2)
    expect_identical(result$status, unname(cases[[code]]), info = code)
    expect_identical(result$http_status, as.integer(code))
    expect_identical(result$final_url, "https://example.org/final")
  }
})

test_that("HEAD fallback occurs only for explicit method rejection", {
  for (rejection in c(405L, 501L)) {
    methods <- character()
    testthat::local_mocked_bindings(fetch_tutorial_url = function(url, method, timeout) {
      methods <<- c(methods, method)
      list(status_code = if (method == "HEAD") rejection else 206L, url = url)
    })
    result <- check_tutorial_url("https://example.org", TRUE, 2)
    expect_identical(methods, c("HEAD", "GET"))
    expect_identical(result$status, "pass")
    expect_identical(result$method, "GET")
  }
})

test_that("transport errors and disabled requests cannot pass", {
  for (message in c("Could not resolve host", "Connection timed out", "TLS error")) {
    calls <- 0L
    testthat::local_mocked_bindings(fetch_tutorial_url = function(...) {
      calls <<- calls + 1L
      stop(message)
    })
    result <- check_tutorial_url("https://example.org", TRUE, 2)
    expect_identical(result$status, "not_run")
    expect_match(result$reason, message, fixed = TRUE)
    expect_identical(calls, 1L)
    expect_identical(check_tutorial_url("https://example.org", FALSE, 2)$status, "not_run")
    expect_identical(calls, 1L)
  }
})

test_that("an unsuccessful GET fallback retains its actual result", {
  testthat::local_mocked_bindings(fetch_tutorial_url = function(url, method, timeout) {
    list(status_code = if (method == "HEAD") 405L else 404L, url = url)
  })
  result <- check_tutorial_url("https://example.org", TRUE, 2)
  expect_identical(result$status, "fail")
  expect_identical(result$method, "GET")
  expect_identical(result$http_status, 404L)
})
