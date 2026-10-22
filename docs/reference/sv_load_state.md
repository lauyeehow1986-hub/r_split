# Load Canvas State from File

Deserializes a previously saved Sideview canvas workspace from a `.json`
or `.rds` file and returns a `sideview_state` object. Optionally
launches an interactive session.

## Usage

``` r
sv_load_state(file, tables = NULL, launch = FALSE, format = NULL)
```

## Arguments

- file:

  Path to the saved state file (`.json` or `.rds`).

- tables:

  Optional named list of data frames or tables to associate with loaded
  cards. If `NULL`, tables are discovered from the calling environment.

- launch:

  Logical; if `TRUE` and the session is interactive, launches
  [`sideview()`](https://lauyeehow1986-hub.github.io/sideview/reference/sideview.md)
  with the loaded state. If non-interactive, returns the loaded state
  object.

- format:

  Optional format specification (`"json"` or `"rds"`). If `NULL`
  (default), the format is inferred from the file extension (`.json` or
  `.rds`).

## Value

A `sideview_state` object of class `c("sideview_state", "list")`, or the
gadget result if `launch = TRUE` in an interactive session.

## Examples

``` r
st <- new_sideview_state()
tf <- tempfile(fileext = ".json")
sv_save_state(st, tf)
loaded <- sv_load_state(tf)
print(loaded)
#> <sideview_state v0.2.0>
#>   Cards:       0
#>   Connections: 0
#>   Canvas:      zoom = 1, pan = (0, 0)
#>   Active Tab:  pipeline
unlink(tf)
```
