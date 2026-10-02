# tutorialverse

tutorialverse provides a shared metadata format for interactive R tutorials
built with `learnr`, `learnr2`, and Quarto Live. The prototype validates YAML
records, checks source and lesson URLs, and optionally renders local tutorials.
Each check reports its own result and limits.

## Installation

From a local checkout, run these commands in R at the repository root:

```r
install.packages(c("yaml", "curl"), repos = "https://cloud.r-project.org")
install.packages(".", repos = NULL, type = "source")
```

The package uses `yaml` to read metadata and `curl` to check URLs. Package checks
passed with R 4.5.1. A minimum supported R version is not yet declared.

## Example

From the repository root, read and validate the included example record:

```r
library(tutorialverse)

metadata <- read_tutorial_metadata("tests/testthat/fixtures/valid.yml")
result <- validate_tutorial_metadata(metadata)
result$status
#> [1] "pass"
result$issues
#> [1] field   code    message
#> <0 rows> (or 0-length row.names)
```

Each result contains a status, the metadata, and a table of issues. To see a
failure, remove the required license field from the parsed record:

```r
incomplete <- metadata$metadata
incomplete$license <- NULL
result <- validate_tutorial_metadata(incomplete)
result$status
#> [1] "fail"
result$issues
#>     field          code                             message
#> 1 license missing_field A required field is absent or null.
```

A successful read means that the file was parsed. Validation applies the
metadata rules. These examples use test records and reserved example URLs.

## Tutorial checks

Use `check_tutorial()` to combine metadata validation and engine checks in one
report. This example disables URL requests because it uses a test record:

```r
report <- check_tutorial(metadata, online = FALSE)
report$metadata$status
#> [1] "pass"
report$source$status
#> [1] "not_run"
report$execution$status
#> [1] "unsupported"
```

The report separates `metadata`, `source`, `lesson`, `render`, `execution`, and
`accessibility`. Each check has a status and reason:

| Status | Meaning |
| --- | --- |
| `pass` | The stated check completed successfully. |
| `fail` | The check found a problem. |
| `not_run` | The check was skipped or could not complete. |
| `unsupported` | The prototype has no implementation for this check. |

URL requests are enabled by default. Broken links can fail independently of
rendering. Network failures, access restrictions, and rate limits are reported
as `not_run` because they leave reachability uncertain.

Rendering is opt-in and runs trusted author code in a temporary copy. Supply
the project directory and a relative entry filename, such as
`check_tutorial(metadata, render = TRUE, tutorial_dir = "my-tutorial",
tutorial_file = "lesson.Rmd")`. The directory must contain the required assets
and configuration. A repository URL alone is not enough.

| Engine | Rendering requirements |
| --- | --- |
| `learnr` | R packages `callr`, `rmarkdown`, `learnr`; Pandoc |
| `learnr2` | R packages `callr`, `quarto`, `learnr2`; Quarto CLI |
| `quarto-live` | R packages `callr`, `quarto`; Quarto CLI and the project's Live extension |

Missing rendering tools produce `not_run`. Install optional R packages from
CRAN, except [learnr2](https://github.com/PPBDS/learnr2), which is available from
GitHub. These dependencies are needed only for the selected renderer.

See the [check reference](man/check_tutorial.Rd) for arguments and failure
handling, and the [adapter reference](man/learnr_adapter.Rd) for supported
document formats.

## Metadata

Each tutorial record requires these eight fields:

```yaml
id: intro-example
title: Introduction to R
engine: learnr
source: https://example.org/source
lesson: https://example.org/lesson
maintainer: Example maintainer
license: MIT
topics:
  - R
  - data frames
```

Supported engine values are `learnr`, `learnr2`, and `quarto-live`. Required text
fields must be nonempty, and `topics` must be a nonempty list of nonempty strings.
IDs use lowercase ASCII letters and digits, with single hyphens between groups.
The source and lesson fields require HTTP(S) URLs.

The optional fields `level`, `packages`, `prerequisites`, `learning_objectives`,
`duration`, `language`, and `deployment` pass through unchanged. Additional
fields also pass through unchanged. The package does not validate these values
or fill in missing values.

To detect duplicate IDs, pass the IDs of other records:

```r
validate_tutorial_metadata(metadata, existing_ids = "intro-example")
```

Without that argument, validation covers one record and cannot establish
uniqueness across a registry.

See the [validation reference](man/validate_tutorial_metadata.Rd) for field
types, URL restrictions, and result details. The
[reading reference](man/read_tutorial_metadata.Rd) describes file handling.

## Prototype status

One real tutorial from each engine rendered successfully during development.
The [adapter review](prototype/adapter-review.md) records the sources and tools.
Rendering proves that a fresh HTML document was built. Interactive exercises
and accessibility remain `unsupported`; a working lesson needs further checks.
Metadata validation also cannot establish ownership or license accuracy.

Curated example records, registry generation with `build_registry()`, CI, and
measurements of author effort are planned for the next feature increment.

## Development

Install the development tools:

```r
install.packages(c("devtools", "roxygen2", "testthat"),
                 repos = "https://cloud.r-project.org")
```

From the repository root, generate the help files, run the tests, and check the
source package:

```r
devtools::document()
devtools::test()
devtools::check(document = FALSE, error_on = "never")
```

Ordinary tests use local files and controlled HTTP and renderer responses.
Set `TUTORIALVERSE_NETWORK_TESTS=true` to enable a live URL check, or
`TUTORIALVERSE_RENDER_TESTS=true` to enable a real learnr render test. These
integration tests are skipped by default. The render test needs the learnr
dependencies listed above.

## License

Released under the [MIT license](LICENSE.md).

## Authors

Shaurita D. Hutchins and Samuel Bharti are co-creators and co-maintainers.

- Shaurita D. Hutchins: <sdhutchins@uab.edu>
- Samuel Bharti: <samuelbharti.io@gmail.com>
