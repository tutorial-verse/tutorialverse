# Adapter evidence

Local review on October 1, 2026. The prototype checks metadata, HTTP responses,
and fresh HTML output separately. The sources below informed adapter behavior
before implementation. They are inspected tutorials, not curated registry records.

## Sources and observed results

| Engine | Tutorial inspected and rendered | Result | What this establishes |
| --- | --- | --- | --- |
| learnr | [Hello, Tutorial!](https://github.com/rstudio/learnr/blob/v0.11.6/inst/tutorials/hello/hello.Rmd), installed with learnr 0.11.6 | `pass`, 48,622 HTML bytes | `learnr::tutorial` builds through R Markdown and Pandoc. |
| learnr2 | [Hello, learnr2](https://github.com/PPBDS/learnr2/blob/d3f68395d5d9ce93c991f6a6d47d80d71ce48bc0/inst/tutorials/hello-learnr2/hello-learnr2.qmd) | `pass`, 81,006 HTML bytes | `live-html` builds with the package's bundled Live extension. |
| Quarto Live | [Creating Exercises](https://github.com/r-wasm/quarto-live/blob/12fb30a5dd5e1bbe6d8ace96795eb1c114c80447/docs/exercises/exercises.qmd) | `pass`, 94,126 HTML bytes | The document builds within its existing Quarto project and Live extension. |

All renders used temporary copies. Checksums and file listings of the source
tutorial directories matched before and after rendering. Output sizes describe
these runs only; they are not regression targets or quality scores.

Environment: R 4.5.1 on macOS, learnr 0.11.6, rmarkdown 2.31, learnr2
0.1.0.9001 at the linked revision, quarto R package 1.5.1, Quarto CLI 1.10.18,
Pandoc 3.11 for the learnr render, and callr 3.8.0.

The learnr sources were supplied with the installed package. For learnr2, the
adapter copied its installed extension into the temporary tutorial directory.
For Quarto Live, the supplied root was the upstream repository checkout and the
entry file was `docs/exercises/exercises.qmd`. Its project assets and extension
were available in that checkout.

The HTTP transport separately returned HTTP 200 for `https://example.org`.
Ordinary regression tests use controlled responses for success, broken links,
redirect outcomes, restricted access, timeouts, offline mode, and HEAD fallback.
The tutorial URLs above were not used as evidence of interactive correctness.

## Capability limits

All three adapters declare metadata and render checks supported. Interactive
execution and accessibility checks are unsupported. Capability flags describe
implemented checks; missing local rendering tools produce `not_run`.

- learnr rendering can catch build-time R failures. It does not start a Shiny
  session, submit exercise answers, or evaluate feedback. The optional integration
  test contrasts a failing build chunk with a failing interactive exercise.
- learnr2 and Quarto Live both use `live-html`. Their format checks overlap and
  cannot independently identify the authoring package. Their browser exercises
  require WebR or Pyodide testing beyond HTML generation.
- Only formats declared in the document header are recognized. Project-inherited
  formats are outside this prototype's scope. `live-revealjs` uses the same render
  path but was not exercised by the three tutorials above.
- A successful HTTP response establishes a response at that time, not tutorial
  content, source identity, or runtime behavior. DNS and transport failures leave
  the link's condition uncertain and produce `not_run`.
- A successful render requires new, nonempty HTML. It does not measure teaching
  quality, exercise correctness, accessibility, or license validity.

## Next evidence to collect

The next increment should add three curated public records, registry output,
and CI. Record which metadata fields were inferred, supplied manually, or remain
unknown, together with time spent by the author. No inference rates or author
effort measurements have been collected in this increment.
