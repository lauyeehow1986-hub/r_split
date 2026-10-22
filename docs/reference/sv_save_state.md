# Save Canvas State to File

Serializes the active Sideview canvas state (cards, positions, filters,
connections, and pipeline code) to either `.json` or `.rds` format.

## Usage

``` r
sv_save_state(state, file, format = NULL)
```

## Arguments

- state:

  A `sideview_state` object or structured state list.

- file:

  Path to the destination file.

- format:

  Optional format specification (`"json"` or `"rds"`). If `NULL`
  (default), the format is inferred from the file extension (`.json` or
  `.rds`).

## Value

Invisibly returns the path of the saved file.

## Examples

``` r
st <- new_sideview_state()
tf <- tempfile(fileext = ".json")
sv_save_state(st, tf)
unlink(tf)
```
