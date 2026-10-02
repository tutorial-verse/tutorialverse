# tutorialverse

tutorialverse provides a shared metadata format for interactive R tutorials
built with `learnr`, `learnr2`, and Quarto Live. The current prototype reads YAML
records and reports missing fields, invalid values, and duplicate IDs.

## Installation

From a local checkout, run these commands in R at the repository root:

```r
install.packages("yaml", repos = "https://cloud.r-project.org")
install.packages(".", repos = NULL, type = "source")
```

The package uses `yaml` to read metadata files. Package checks passed with
R 4.5.1. A minimum supported R version is not yet declared.

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

This version validates metadata locally, including known failures in test
records. It does not contact tutorial URLs, render tutorials, or run exercises.
A passing result does not establish that a tutorial works or that its
maintainer and license information is accurate.

Engine adapters, `check_tutorial()`, real tutorial examples, registry generation
with `build_registry()`, and automated CI checks are planned. Evidence that the
shared interface works across engines still requires those steps.

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

Tests use local files and do not require network access.

## License

Released under the [MIT license](LICENSE.md).

## Authors

Shaurita D. Hutchins and Samuel Bharti are co-creators and co-maintainers.

- Shaurita D. Hutchins: <sdhutchins@uab.edu>
- Samuel Bharti: <samuelbharti.io@gmail.com>
