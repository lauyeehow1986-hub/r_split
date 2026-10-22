# Generate tidyverse Code for Reshaping Data from Long to Wide

Constructs syntactically valid
[`tidyr::pivot_wider()`](https://tidyr.tidyverse.org/reference/pivot_wider.html)
calls with proper identifier escaping and optional aggregation
functions.

## Usage

``` r
sv_code_pivot_wider(
  df_name = NULL,
  names_from,
  values_from,
  values_fn = NULL,
  pipe = FALSE
)
```

## Arguments

- df_name:

  Name of the data frame (optional; can be NULL for piped workflows).

- names_from:

  Character vector of column name(s) to get the name of the output
  column from.

- values_from:

  Character vector of column name(s) to get the cell values from.

- values_fn:

  Optional function name (character string or named vector/list) to
  apply to values. Defaults to `NULL`.

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% tidyr::pivot_wider(...)`.
  Defaults to `FALSE`.

## Value

A character string of R code.
