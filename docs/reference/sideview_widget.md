# Create a Standalone Sideview HTMLWidget

Normalizes passed table objects (`data.frame`, `tibble`, `table`, `gt`,
`flextable`, `htmlwidgets`) and creates an interactive 2D infinite
canvas `htmlwidget` suitable for rendering in R Markdown, Quarto, Shiny,
or exporting via
[`save_sideview()`](https://lauyeehow1986-hub.github.io/r_split/reference/save_sideview.md).

## Usage

``` r
sideview_widget(
  ...,
  width = NULL,
  height = NULL,
  elementId = NULL,
  options = list()
)
```

## Arguments

- ...:

  Arbitrary table objects (`data.frame`, `tibble`, `table`, `gt`,
  `flextable`, `htmlwidgets`), named or unnamed, or a single list of
  tables.

- width:

  Optional widget width (e.g. `"100%"`).

- height:

  Optional widget height (e.g. `"600px"`).

- elementId:

  Optional HTML element identifier.

- options:

  Named list of canvas options (e.g. `snapToEdge`, `snapThreshold`,
  `minScale`, `maxScale`).

## Value

An S3 object of class `c("sideview", "htmlwidget")`.

## Examples

``` r
if (interactive()) {
  sideview_widget(mtcars, iris)
}
```
