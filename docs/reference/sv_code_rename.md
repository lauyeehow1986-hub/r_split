# Generate tidyverse Code for Column Renaming

Generate tidyverse Code for Column Renaming

## Usage

``` r
sv_code_rename(df_name, old_col, new_col, pipe = FALSE)
```

## Arguments

- df_name:

  Name of the data frame.

- old_col:

  Existing column name(s).

- new_col:

  New column name(s).

- pipe:

  Logical; if TRUE, uses pipe syntax `df %>% dplyr::rename(...)`.

## Value

A character string of R code.
