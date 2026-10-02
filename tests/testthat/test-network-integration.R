test_that("an optional live URL check completes or skips offline", {
  skip_if(Sys.getenv("TUTORIALVERSE_NETWORK_TESTS") != "true",
          "Set TUTORIALVERSE_NETWORK_TESTS=true to enable live HTTP checks.")
  result <- check_tutorial_url("https://example.org", TRUE, 10)
  skip_if(result$status == "not_run", result$reason)
  expect_identical(result$status, "pass")
})
