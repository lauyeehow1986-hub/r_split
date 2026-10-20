# Build Structured Prompt for Tidyverse LLM Code Generation

Formats system instructions emphasizing pure, executable tidyverse R
code enclosed in markdown code fences (```` ```r ... ``` ````) and
packages user task description alongside privacy-safe table schemas.

## Usage

``` r
sv_build_prompt(user_prompt, schema_context = NULL)
```

## Arguments

- user_prompt:

  Natural language description of desired data transformation.

- schema_context:

  Optional privacy-safe schema string built via
  `sv_build_schema_context`.

## Value

A list of class `sideview_prompt` containing `system_message`,
`user_message`, and `prompt`.
