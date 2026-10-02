read_fixture <- function(name) {
  read_tutorial_metadata(testthat::test_path("fixtures", name))
}

valid_metadata <- function() {
  read_fixture("valid.yml")$metadata
}

test_that("valid YAML has a stable structured result", {
  parsed <- read_fixture("valid.yml")
  result <- validate_tutorial_metadata(parsed)

  expect_s3_class(result, "tutorial_metadata_result")
  expect_named(result, c("status", "metadata", "issues"))
  expect_identical(result$status, "pass")
  expect_identical(result$metadata, parsed$metadata)
  expect_named(result$issues, c("field", "code", "message"))
  expect_identical(nrow(result$issues), 0L)
  expect_true(all(vapply(result$issues, is.character, logical(1))))
})

test_that("all supported engines pass the same metadata contract", {
  for (engine in c("learnr", "learnr2", "quarto-live")) {
    metadata <- valid_metadata()
    metadata$engine <- engine
    expect_identical(validate_tutorial_metadata(metadata)$status, "pass")
  }
})

test_that("missing required fields are reported together", {
  parsed <- read_fixture("missing-metadata.yml")
  expect_identical(parsed$status, "pass")
  result <- validate_tutorial_metadata(parsed)

  expect_identical(result$status, "fail")
  expect_setequal(
    result$issues$field,
    c("title", "source", "lesson", "maintainer", "license", "topics")
  )
  expect_true(all(result$issues$code == "missing_field"))

  metadata <- valid_metadata()
  metadata["title"] <- list(NULL)
  expect_identical(
    validate_tutorial_metadata(metadata)$issues$code, "missing_field"
  )
})

test_that("required text fields reject empty and non-scalar values", {
  invalid_values <- list("", "  \t\n", NA_character_, 1, TRUE, c("a", "b"),
                         list("a"), character(), matrix("a"))
  for (field in setdiff(names(valid_metadata()), "topics")) {
    for (value in invalid_values) {
      metadata <- valid_metadata()
      metadata[field] <- list(value)
      result <- validate_tutorial_metadata(metadata)
      expect_identical(result$status, "fail", info = field)
      expect_true("invalid_type" %in% result$issues$code, info = field)
    }
  }
})

test_that("topics are a nonempty sequence of strings", {
  invalid_topics <- list(
    character(), list(), c("R", ""), c("R", NA_character_),
    c("R", " "), list("R", 2), list(list("R")), c(topic = "R"),
    list(topic = "R"), TRUE, 1, matrix("R")
  )
  for (topics in invalid_topics) {
    metadata <- valid_metadata()
    metadata$topics <- topics
    expect_identical(validate_tutorial_metadata(metadata)$issues$code, "invalid_type")
  }
  for (topics in list("R", c("R", "data frames"), list("R", "data frames"))) {
    metadata <- valid_metadata()
    metadata$topics <- topics
    expect_identical(validate_tutorial_metadata(metadata)$status, "pass")
  }
})

test_that("unknown engines and malformed URLs identify their fields", {
  engine <- validate_tutorial_metadata(read_fixture("invalid-engine.yml"))
  expect_identical(engine$status, "fail")
  expect_identical(engine$issues$field, "engine")
  expect_identical(engine$issues$code, "unsupported_engine")

  urls <- validate_tutorial_metadata(read_fixture("malformed-url.yml"))
  expect_identical(urls$status, "fail")
  expect_identical(urls$issues$field, c("source", "lesson"))
  expect_true(all(urls$issues$code == "invalid_url"))
})

test_that("URL syntax checks reject malformed hosts, ports, and escapes", {
  invalid_urls <- c(
    "ftp://example.org", "https:///lesson", "https://example.org/a b",
    "https://example.org\n", "https://user:password@example.org",
    "https://example..org", "https://-example.org", "https://example-.org",
    "https://example_org", "https://.example.org", "https://example.org.",
    "https://example.org:", "https://example.org:0", "https://example.org:65536",
    "https://example.org:999999999999", "https://example.org:abc",
    "https://256.0.0.1", "https://127.1", "https://001.2.3.4",
    "https://example.org/%", "https://example.org/%FG",
    "https://example.org/\\lesson", "https://example.org/<lesson>",
    "https://[::1]/", paste0("https://", strrep("a", 64), ".org")
  )
  for (url in invalid_urls) {
    metadata <- valid_metadata()
    metadata$source <- url
    result <- validate_tutorial_metadata(metadata)
    expect_identical(result$issues$code, "invalid_url", info = url)
  }
})

test_that("valid URL forms pass without testing reachability", {
  urls <- c(
    "https://example.org", "http://localhost:8080/lesson",
    "https://127.0.0.1:65535/path", "https://example.org:1/",
    "HTTPS://EXAMPLE.ORG/lesson?q=R%20tutorial#section",
    "https://xn--bcher-kva.example/", "https://example.org?lesson=1",
    "https://example.org/#lesson", "https://does-not-exist.invalid/lesson"
  )
  for (url in urls) {
    metadata <- valid_metadata()
    metadata$lesson <- url
    expect_identical(validate_tutorial_metadata(metadata)$status, "pass", info = url)
  }
})

test_that("tutorial IDs have an explicit grammar", {
  for (id in c("Intro", "intro_example", "intro--example", "-intro", "intro-",
               "intro example", "intro/example", "intro\n", "intro ")) {
    metadata <- valid_metadata()
    metadata$id <- id
    expect_identical(validate_tutorial_metadata(metadata)$issues$code, "invalid_id")
  }
  for (id in c("a", "123", "intro-2-r")) {
    metadata <- valid_metadata()
    metadata$id <- id
    expect_identical(validate_tutorial_metadata(metadata)$status, "pass")
  }
})

test_that("duplicate IDs require explicit context from other records", {
  first <- read_fixture("valid.yml")
  second <- read_fixture("duplicate-id.yml")
  expect_identical(validate_tutorial_metadata(second)$status, "pass")
  result <- validate_tutorial_metadata(second, existing_ids = first$metadata$id)
  expect_identical(result$status, "fail")
  expect_identical(result$issues$field, "id")
  expect_identical(result$issues$code, "duplicate_id")
  expect_identical(
    validate_tutorial_metadata(second, existing_ids = "another-id")$status, "pass"
  )
})

test_that("invalid duplicate-ID context fails instead of implying uniqueness", {
  for (ids in list(NULL, 1, NA_character_, "", " ", list("intro-example"),
                   matrix("another-id"))) {
    result <- validate_tutorial_metadata(valid_metadata(), existing_ids = ids)
    expect_identical(result$status, "fail")
    expect_true("invalid_context" %in% result$issues$code)
  }
})

test_that("malformed YAML and duplicate YAML keys preserve read failures", {
  for (fixture in c("malformed.yml", "duplicate-key.yml")) {
    parsed <- read_fixture(fixture)
    expect_identical(parsed$status, "fail")
    expect_null(parsed$metadata)
    expect_identical(parsed$issues$code, "read_error")
    expect_true(nzchar(parsed$issues$message))
    expect_identical(validate_tutorial_metadata(parsed), parsed)
  }
})

test_that("invalid paths produce structured failures", {
  for (path in list(NULL, NA_character_, "", character(), c("a", "b"), 1)) {
    result <- read_tutorial_metadata(path)
    expect_identical(result$status, "fail")
    expect_identical(result$issues$code, "invalid_path")
  }
  for (path in c(tempfile(), tempdir())) {
    result <- read_tutorial_metadata(path)
    expect_identical(result$status, "fail")
    expect_identical(result$issues$code, "unreadable_file")
  }
})

test_that("metadata must be a single mapping with unique keys", {
  for (metadata in list(NULL, "id", 1, list("id"), data.frame(id = "example"),
                        stats::setNames(list("value"), ""))) {
    expect_identical(
      validate_tutorial_metadata(metadata)$issues$code, "invalid_mapping"
    )
  }
  metadata <- valid_metadata()
  metadata <- c(metadata, metadata["id"])
  expect_identical(validate_tutorial_metadata(metadata)$issues$code, "duplicate_key")

  path <- tempfile(fileext = ".yml")
  on.exit(unlink(path), add = TRUE)
  for (content in c("", "hello", "- a\n- b")) {
    writeLines(content, path)
    expect_identical(read_tutorial_metadata(path)$issues$code, "invalid_mapping")
  }
})

test_that("YAML expressions cannot execute R code", {
  path <- tempfile(fileext = ".yml")
  sentinel <- tempfile()
  on.exit(unlink(c(path, sentinel)), add = TRUE)
  expression <- sprintf("file.create('%s')", sentinel)
  writeLines(paste("id: !expr", expression), path)

  # A real filesystem sentinel detects execution, not merely a parser option.
  result <- read_tutorial_metadata(path)
  expect_false(file.exists(sentinel))
  expect_identical(result$status, "pass")
  expect_identical(result$metadata$id, expression)
})

test_that("optional metadata is preserved without inference or mutation", {
  metadata <- valid_metadata()
  metadata$level <- "beginner"
  metadata$packages <- c("stats", "utils")
  metadata$prerequisites <- NA_character_
  metadata$learning_objectives <- list("Read a data frame")
  metadata$duration <- 10
  metadata$language <- "en"
  metadata$deployment <- NULL
  metadata$custom <- list(source_note = "Synthetic")
  original <- metadata
  result <- validate_tutorial_metadata(metadata)

  expect_identical(result$status, "pass")
  expect_identical(result$metadata, original)
  expect_identical(metadata, original)
  expect_false("deployment" %in% names(result$metadata))
  expect_identical(result, validate_tutorial_metadata(metadata))
})

test_that("YAML files do not require a final newline", {
  path <- tempfile(fileext = ".yml")
  on.exit(unlink(path), add = TRUE)
  cat("id: example", file = path)
  expect_identical(read_tutorial_metadata(path)$status, "pass")
})
