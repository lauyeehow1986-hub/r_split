# Sideview User Interface

Builds the complete 2D infinite canvas user interface for Sideview,
containing the draggable table cards, panzoom canvas, SVG connector
overlay, action drawer, and natural language AI bar with all HTML
dependencies attached.

## Usage

``` r
sideview_ui(cards = list(), title = "Sideview Canvas")
```

## Arguments

- cards:

  A `sideview_card` object, a list of `sideview_card` objects, or
  tabular objects to be normalized.

- title:

  Display title for the application toolbar. Default is "Sideview
  Canvas".

## Value

A `shiny.tag.list` UI definition.
