# Generate tidyverse Code for Reshaping Data from Wide to Long

Constructs syntactically valid
[`tidyr::pivot_longer()`](https://tidyr.tidyverse.org/reference/pivot_longer.html)
calls with proper identifier escaping and support for both piped
workflows and direct calls.

## Usage

``` r
sv_code_pivot_longer(
  df_name = NULL,
  cols,
  names_to = "name",
  values_to = "value",
  pipe = FALSE
)
```

## Arguments

- df_name:

  Name of the data frame (optional; can be NULL for piped workflows).

- cols:

  Character vector of column name(s) to pivot into longer format.

- names_to:

  Character string specifying the name of the column to create from the
  data stored in the column names of `cols`. Defaults to `"name"`.

- values_to:

  Character string specifying the name of the column to create from the
  data stored in cell values. Defaults to `"value"`.

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% tidyr::pivot_longer(...)`.
  Defaults to `FALSE`.

## Value

A character string of R code.
