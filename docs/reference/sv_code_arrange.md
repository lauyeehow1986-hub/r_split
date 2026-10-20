# Generate tidyverse Code for Arranging (Sorting) Rows

Generate tidyverse Code for Arranging (Sorting) Rows

## Usage

``` r
sv_code_arrange(df_name, col, desc = FALSE, pipe = FALSE)
```

## Arguments

- df_name:

  Name of the data frame.

- col:

  Character vector of column name(s) to sort by.

- desc:

  Logical vector indicating descending order for each column. Recycled
  to match the length of `col`. Defaults to `FALSE`.

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% dplyr::arrange(...)`.

## Value

A character string of R code.
