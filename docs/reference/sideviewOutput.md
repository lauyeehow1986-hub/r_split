# Shiny Output Container for Sideview Widget

Shiny Output Container for Sideview Widget

## Usage

``` r
sideviewOutput(outputId, width = "100%", height = "600px")
```

## Arguments

- outputId:

  Output variable to read from.

- width, height:

  Must be a valid CSS unit (e.g. `'100%'`, `'600px'`, `'auto'`) or a
  number, which will be coerced to a string and have `'px'` appended.

## Value

A `shiny.tag` object representing the widget container.
