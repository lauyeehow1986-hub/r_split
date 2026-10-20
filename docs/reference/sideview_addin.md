# RStudio Addin for Sideview

Automatically discovers tabular datasets in the user's active
environment and launches the Sideview interactive multi-table canvas
gadget.

## Usage

``` r
sideview_addin(
  env = .GlobalEnv,
  viewer = shiny::paneViewer(minHeight = 500),
  run = interactive()
)
```

## Arguments

- env:

  Environment to search for tables (defaults to `.GlobalEnv`).

- viewer:

  Shiny viewer gadget display mode (default
  [`shiny::paneViewer()`](https://rdrr.io/pkg/shiny/man/viewer.html)).

- run:

  Logical indicating whether to execute the gadget. Default
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

Result of `sideview(...)`.
