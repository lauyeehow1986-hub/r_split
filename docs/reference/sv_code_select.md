# Generate tidyverse Code for Selecting Columns

Generate tidyverse Code for Selecting Columns

## Usage

``` r
sv_code_select(df_name, cols, pipe = FALSE)
```

## Arguments

- df_name:

  Name of the data frame.

- cols:

  Character vector of column names to select.

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% dplyr::select(...)`.

## Value

A character string of R code.
