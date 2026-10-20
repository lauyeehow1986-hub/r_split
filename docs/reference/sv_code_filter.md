# Generate tidyverse Code for Filtering Rows

Generate tidyverse Code for Filtering Rows

## Usage

``` r
sv_code_filter(df_name, condition, pipe = FALSE)
```

## Arguments

- df_name:

  Name of the data frame.

- condition:

  Character vector of boolean filter expressions.

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% dplyr::filter(...)`.

## Value

A character string of R code.
