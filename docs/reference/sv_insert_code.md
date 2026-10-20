# Insert Generated Code into the Active RStudio Editor

Inserts tidyverse pipelines or generated code directly into the user's
active document buffer at the current cursor location via
[`rstudioapi::insertText()`](https://rstudio.github.io/rstudioapi/reference/rstudio-documents.html).
If RStudio is unavailable, running headless, or if no document is
currently open, falls back gracefully by returning a structured status
list containing the code.

## Usage

``` r
sv_insert_code(code, location = NULL, ...)
```

## Arguments

- code:

  Character vector or scalar string containing the code to insert.
  Multiple elements are joined by newline characters.

- location:

  Optional cursor position or range for
  [`rstudioapi::insertText()`](https://rstudio.github.io/rstudioapi/reference/rstudio-documents.html).
  Defaults to `NULL` (current selection/cursor).

- ...:

  Additional arguments passed to
  [`rstudioapi::insertText()`](https://rstudio.github.io/rstudioapi/reference/rstudio-documents.html).

## Value

A named list with:

- success:

  Logical indicating whether insertion into editor succeeded.

- destination:

  Character `"editor"` on success, `"fallback"` on fallback/error.

- code:

  Character string of the normalized code.

- message:

  Character description of the result or error.

## Examples

``` r
res <- sv_insert_code("library(dplyr)")
```
