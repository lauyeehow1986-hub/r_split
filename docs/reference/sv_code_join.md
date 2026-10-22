# Generate tidyverse Code for Relational Table Joins

Generate tidyverse Code for Relational Table Joins

## Usage

``` r
sv_code_join(df1, df2, col1, col2 = col1, join_type = "left", pipe = FALSE)
```

## Arguments

- df1:

  Name of the first data frame (optional / can be NULL when constructing
  intermediate piped join segments).

- df2:

  Name of the second data frame.

- col1:

  Key column name(s) in df1.

- col2:

  Key column name(s) in df2 (defaults to col1).

- join_type:

  Type of join: "left", "inner", "anti", "right", "full", "semi".

- pipe:

  Logical; if TRUE, uses pipe syntax
  `df1 %>% dplyr::<join_type>(df2, ...)`.

## Value

A character string of R code.
