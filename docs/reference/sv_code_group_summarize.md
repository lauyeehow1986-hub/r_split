# Generate tidyverse Code for Grouping and Aggregating Data

Constructs syntactically valid
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
and
[`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
pipelines with identifier escaping, customizable summary metrics, and
reproducible grouping behavior via `.groups = 'drop'`.

## Usage

``` r
sv_code_group_summarize(
  df_name = NULL,
  group_cols,
  summary_exprs,
  pipe = FALSE
)
```

## Arguments

- df_name:

  Name of the data frame (optional; can be NULL for intermediate piped
  pipeline segments).

- group_cols:

  Character vector of grouping column name(s).

- summary_exprs:

  Named character vector or named list of aggregation expressions (e.g.,
  `c(total = "dplyr::n()", avg = "mean(val, na.rm = TRUE)")`).

- pipe:

  Logical; if TRUE, uses pipe syntax
  `df %>% dplyr::group_by(...) %>% dplyr::summarise(...)`. Defaults to
  `FALSE`.

## Value

A character string of R code.
