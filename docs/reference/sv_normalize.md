# Universal Normalization Engine for Sideview Cards

Converts various R table formats (data.frame, tibble, table, gt,
flextable, htmlwidgets) into a standardized `sideview_card` S3 object
for rendering on the 2D infinite canvas.

## Usage

``` r
sv_normalize(x, name = NULL, id = NULL, ...)
```

## Arguments

- x:

  An object to normalize (data.frame, tibble, table, gt, flextable,
  htmlwidget).

- name:

  Optional display name for the card.

- id:

  Optional unique identifier for the card.

- ...:

  Additional arguments passed to methods.

## Value

An object of class `sideview_card`.
