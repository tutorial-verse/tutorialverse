# tutorialverse

A minimal R package for describing and validating interactive R tutorials.
This first prototype increment validates metadata for `learnr`, `learnr2`, and
Quarto Live. It does not execute or render tutorials.

## Creators and maintainers

Shaurita D. Hutchins and Samuel Bharti are co-creators and co-maintainers.

- Shaurita D. Hutchins: <sdhutchins@uab.edu> (designated R package maintainer)
- Samuel Bharti: <samuelbharti.io@gmail.com>

Copyright (c) 2026 Shaurita D. Hutchins and Samuel Bharti.
Released under the [MIT license](LICENSE.md).

## Try the metadata validator

From the repository root, with the development dependencies installed:

```r
devtools::load_all()
metadata <- read_tutorial_metadata("tests/testthat/fixtures/valid.yml")
result <- validate_tutorial_metadata(metadata)
result$status
result$issues
```

The fixture is synthetic and uses reserved example URLs. It is not evidence
that a real tutorial works. No network connection is made during validation.

## Metadata contract

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

All eight fields are required. Text fields must be nonempty strings. `topics`
must be a nonempty sequence of nonempty strings. Quote YAML values that might
otherwise become numbers or booleans. IDs use lowercase ASCII letters and
digits, with single hyphens between groups. Supported engines are `learnr`,
`learnr2`, and `quarto-live`.

`source` and `lesson` must be HTTP(S) URLs with ASCII DNS hostnames or IPv4
addresses. Localhost and ports from 1 to 65535 are accepted. This deliberately
limited URL contract excludes IPv6 literals, embedded credentials, unencoded
whitespace, malformed percent escapes, and trailing-dot hostnames.
International hostnames must use ASCII encoding. URL syntax does not establish
reachability, repository identity, or the presence of a tutorial.

The optional fields `level`, `packages`, `prerequisites`, `learning_objectives`,
`duration`, `language`, and `deployment` are preserved without validation.
Additional fields are also preserved. Missing values are never invented.
Maintainer and license strings are required, but their accuracy and licensing
permissions are not checked.

## Structured results

Both public functions return `status`, `metadata`, and `issues`. The issues
data frame contains `field`, `code`, and `message` columns. A successful result
has zero issue rows. The returned object has class `tutorial_metadata_result`.

A passing read means only that a file was parsed as a mapping. The validator
checks the required fields. It accepts either a read result or a named R list
and returns all detected field problems together. Read failures retain their
original issues. YAML expression evaluation is disabled, and expression-tagged
values are treated as literal text. Duplicate keys and parsing warnings fail
the read. Invalid top-level structures fail before field validation.

To detect duplicate tutorial IDs, supply the IDs of **other** records:

```r
validate_tutorial_metadata(metadata, existing_ids = "intro-example")
```

Without that context, a single-record validator cannot establish uniqueness.

## Development

Runtime dependency: `yaml` for parsing. `testthat` is a suggested dependency for
tests. Package scaffolding uses `usethis`; documentation and source-package
checks use `devtools` and `roxygen2`. `jsonlite` and `cli` will be introduced when
registry generation or reporting needs them.

```r
devtools::document()
devtools::test()
devtools::check(document = FALSE, error_on = "never")
```

Tests use local fixtures and do not require network access. Adapters,
`check_tutorial()`, real registry entries, `build_registry()`, and CI are planned
for the next two increments and are not implemented here.
