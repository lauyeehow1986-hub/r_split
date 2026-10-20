# Multi-Table 2D Infinite Canvas Interactive Gadget

Launches an interactive Shiny gadget containing an infinite 2D canvas
with mouse-wheel zoom, pan, draggable table cards, interactive column
mapping, discrepancy recoding, and LLM-assisted tidyverse code
generation.

## Usage

``` r
sideview(
  ...,
  title = "Sideview Canvas",
  viewer = shiny::paneViewer(minHeight = 500),
  run = interactive()
)
```

## Arguments

- ...:

  Arbitrary table objects (`data.frame`, `tibble`, `matrix`, `table`,
  `gt`, `flextable`, `htmlwidgets`), named or unnamed.

- title:

  Title for the gadget viewer.

- viewer:

  Shiny viewer gadget display mode (e.g.
  [`shiny::paneViewer()`](https://rdrr.io/pkg/shiny/man/viewer.html),
  [`shiny::dialogViewer()`](https://rdrr.io/pkg/shiny/man/viewer.html),
  or
  [`shiny::browserViewer()`](https://rdrr.io/pkg/shiny/man/viewer.html)).

- run:

  Logical; if `TRUE`, launches the interactive gadget via
  [`shiny::runGadget()`](https://rdrr.io/pkg/shiny/man/runGadget.html).
  If `FALSE`, returns the `shiny.appobj` definition without launching
  (useful for testing or embedding). Defaults to
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

If `run = TRUE`, returns the result of
[`shiny::runGadget()`](https://rdrr.io/pkg/shiny/man/runGadget.html). If
`run = FALSE`, returns a `shiny.appobj` with the normalized cards
attached.

## Examples

``` r
if (interactive()) {
  sideview(mtcars, iris)
}
```
