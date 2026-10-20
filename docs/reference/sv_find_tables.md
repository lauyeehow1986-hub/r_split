# Find Tabular Data Objects in an Environment

Scans an environment for tabular objects, including `data.frame`,
`tibble`, `matrix`, `table`, `gt`, `flextable`, and `sideview_card`
objects.

## Usage

``` r
sv_find_tables(env = parent.frame())
```

## Arguments

- env:

  Environment to scan (defaults to
  [`parent.frame()`](https://rdrr.io/r/base/sys.parent.html)).

## Value

A named list of tabular objects found in the environment.
