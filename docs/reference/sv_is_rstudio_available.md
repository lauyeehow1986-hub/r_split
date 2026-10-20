# Check if RStudio API is Available

Safely tests whether the RStudio API is running and operational in the
current session without raising errors in headless, testing, or CI
environments.

## Usage

``` r
sv_is_rstudio_available()
```

## Value

Logical scalar (`TRUE` if RStudio is running and accessible, `FALSE`
otherwise).

## Examples

``` r
sv_is_rstudio_available()
#> [1] FALSE
```
