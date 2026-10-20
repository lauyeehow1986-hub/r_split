# Shiny Render Function for Sideview Widget

Shiny Render Function for Sideview Widget

## Usage

``` r
renderSideview(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- expr:

  An expression that generates a
  [`sideview_widget`](https://lauyeehow1986-hub.github.io/sideview/reference/sideview_widget.md).

- env:

  The environment in which to evaluate `expr`.

- quoted:

  Is `expr` a quoted expression (with
  [`quote()`](https://rdrr.io/r/base/substitute.html))? Default `FALSE`.

## Value

An S3 object of class `c("shiny.render.function", "function")`.
