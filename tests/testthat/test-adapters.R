test_that("each adapter exposes explicit prototype capabilities", {
  adapters <- list(learnr_adapter(), learnr2_adapter(), quarto_live_adapter())
  expect_identical(vapply(adapters, `[[`, character(1), "engine"),
                   c("learnr", "learnr2", "quarto-live"))
  for (adapter in adapters) {
    expect_true(adapter$metadata_supported)
    expect_true(adapter$render_check_supported)
    expect_false(adapter$execution_check_supported)
    expect_false(adapter$accessibility_check_supported)
    expect_true(nzchar(adapter$execution_reason))
    expect_identical(get_adapter(adapter$engine), adapter)
  }
  expect_identical(adapters[[1]]$render_backend, "rmarkdown")
  expect_identical(adapters[[2]]$render_backend, "quarto")
  expect_identical(adapters[[3]]$render_backend, "quarto")
  expect_true("learnr2" %in% adapters[[2]]$render_packages)
  expect_false("learnr2" %in% adapters[[3]]$render_packages)
})

test_that("unknown engines have no adapter", {
  for (engine in list(NULL, NA_character_, "unknown", c("learnr", "learnr2"))) {
    expect_null(get_adapter(engine))
  }
})
