# Build a Privacy-Safe Schema Context from Sideview Cards

Summarizes the metadata of sideview cards (table names, dimensions,
column names, types, value ranges for numerics/dates, sample levels for
factors, and unique samples for characters) without leaking full raw row
data or records. Non-tabular widget cards and NULL data are handled
safely.

## Usage

``` r
sv_build_schema_context(cards, max_categories = 5L)
```

## Arguments

- cards:

  A `sideview_card`, a list of `sideview_card`s, or tabular data.

- max_categories:

  Maximum sample unique categories to report for categorical columns.
  Default is 5.

## Value

A character string containing the privacy-safe schema summary.
