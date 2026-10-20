# Generate tidyverse Code for Column Mutation

Generate tidyverse Code for Column Mutation

## Usage

``` r
sv_code_mutate(df_name, new_col, expr, pipe = FALSE)
```

## Arguments

- df_name:

  Name of the data frame.

- new_col:

  Name of the column(s) being created or transformed.

- expr:

  R expression string(s) to evaluate.

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% dplyr::mutate(...)`.

## Value

A character string of R code.
