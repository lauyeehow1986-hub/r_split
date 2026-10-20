# Send Generated Code to the RStudio Console

Sends R code to the RStudio console for immediate evaluation or user
inspection. Falls back gracefully without crashing if RStudio is
unavailable or running in a headless environment.

## Usage

``` r
sv_send_to_console(code, execute = TRUE, ...)
```

## Arguments

- code:

  Character vector or scalar string containing the code to execute.
  Multiple elements are joined by newline characters.

- execute:

  Logical indicating whether to execute the code immediately (`TRUE`) or
  simply populate the console line without executing (`FALSE`). Default
  `TRUE`.

- ...:

  Additional arguments passed to
  [`rstudioapi::sendToConsole()`](https://rstudio.github.io/rstudioapi/reference/sendToConsole.html).

## Value

A named list with:

- success:

  Logical indicating whether console transmission succeeded.

- destination:

  Character `"console"` on success, `"fallback"` on fallback/error.

- code:

  Character string of the normalized code.

- message:

  Character description of the result or error.

## Examples

``` r
res <- sv_send_to_console("1 + 1", execute = FALSE)
```
