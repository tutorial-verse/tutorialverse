# Adapter review

## Purpose

Tutorialverse supports tutorials built with learnr, learnr2, and Quarto Live.
Each system has an adapter, a small component that checks the tutorial's
information and builds its HTML file.

## What we checked

On October 1, 2026, we tested one example tutorial from each system. All three
produced a new HTML file containing output. We worked with temporary copies and
verified that the original files were preserved by comparing file listings and
checksums before and after each build.

We checked website responses separately. A request to `https://example.org`
returned HTTP 200, a successful response. Automated tests cover several response
and connection conditions.

## What the results establish

The review establishes that the adapters can build these examples with the
required software and project files available. Each adapter reads the format
specified at the top of the tutorial and uses the corresponding build tools.
learnr2 and Quarto Live share the same `live-html` format.

The current checks cover tutorial information, website responses, and HTML
builds. A successful website response records that the server answered at the
time of the check. Confirming the page's content and source requires a separate
review.

Checking the learner's experience requires an interactive session where someone
submits answers and examines feedback. Accessibility, teaching quality, and
licensing also require their own reviews.

## Next steps

The next step is to add three curated public tutorials to the registry, produce
registry output, and run the checks automatically through GitHub. That work will
also record which information was inferred or supplied manually, which details
need follow-up, and how much time authors spent preparing it. Measuring inference
rates and author effort belongs to that next stage.

## Reference details

### Example tutorials

These examples informed the adapter implementation. They serve as build examples;
curating public registry records is the next stage.

| System | Example | Build result |
| --- | --- | --- |
| learnr | [Hello, Tutorial!](https://github.com/rstudio/learnr/blob/v0.11.6/inst/tutorials/hello/hello.Rmd) | `pass` |
| learnr2 | [Hello, learnr2](https://github.com/PPBDS/learnr2/blob/d3f68395d5d9ce93c991f6a6d47d80d71ce48bc0/inst/tutorials/hello-learnr2/hello-learnr2.qmd) | `pass` |
| Quarto Live | [Creating Exercises](https://github.com/r-wasm/quarto-live/blob/12fb30a5dd5e1bbe6d8ace96795eb1c114c80447/docs/exercises/exercises.qmd) | `pass` |

The learnr example came from the installed package and built through R Markdown
and Pandoc. The learnr2 adapter copied its installed Live extension into the
temporary tutorial directory. Quarto Live used the upstream repository as its
project root, including its assets and extension, with
`docs/exercises/exercises.qmd` as the entry file.

### Adapter behavior

- All three adapters support metadata and HTML build checks. A `not_run` result
  means a check needs the required build tools or a working connection before it
  can establish a result.
- Format detection reads the tutorial's own header. Recognizing project-level
  formats and testing `live-revealjs` are follow-up work. Identifying learnr2 or
  Quarto Live specifically requires information beyond their shared format.
- learnr builds can catch errors in R code executed during the build. Its optional
  integration test distinguishes build errors from interactive exercise errors.
  Exercise testing requires Shiny for learnr and WebR or Pyodide for the Live
  formats.
- Website tests use controlled responses for success, broken links, redirects,
  restricted access, timeouts, offline mode, and a second request when HEAD is
  unsuitable. DNS and transport errors receive `not_run` because the link's
  condition needs further checking.

### Software versions

The review ran on macOS with R 4.5.1, learnr 0.11.6, rmarkdown 2.31, learnr2
0.1.0.9001 at the linked revision, quarto R package 1.5.1, Quarto CLI 1.10.18,
and callr 3.8.0. The learnr build used Pandoc 3.11.
