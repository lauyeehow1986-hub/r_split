# Extract Executable R Code from LLM Response Text

Parses code fence blocks (```` ```r ... ``` ````,
```` ```R ... ``` ````, ```` ``` ... ``` ````) out of LLM responses. If
multiple fences exist, concatenates them. If no fence is found, falls
back to the trimmed raw text. Strips extraneous whitespace and returns
valid R code.

## Usage

``` r
sv_extract_code(response_text)
```

## Arguments

- response_text:

  Character vector containing the LLM response text.

## Value

A character string of extracted R code.
