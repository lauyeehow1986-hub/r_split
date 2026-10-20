# Detect Exact Matches, Discrepancies, and Fuzzy Near-Matches

Compares distinct values between two vectors (e.g. columns mapped across
tables), computing exact matches, values only in x, values only in y,
fuzzy/near-matches using Levenshtein distance (adist), and comprehensive
match statistics.

## Usage

``` r
sv_detect_discrepancies(x, y, max_distance = 2)
```

## Arguments

- x:

  Vector of values from the first column.

- y:

  Vector of values from the second column.

- max_distance:

  Maximum Levenshtein edit distance for fuzzy matching (default 2).

## Value

A list with elements:

- `exact_matches`: character vector of values present in both x and y.

- `fuzzy_matches`: data.frame with columns `x`, `y`, `distance`.

- `only_in_x`: character vector of values present only in x.

- `only_in_y`: character vector of values present only in y.

- `stats`: list of match statistics (counts, NA counts, match rate).

- `match_stats`: alias to `stats`.
