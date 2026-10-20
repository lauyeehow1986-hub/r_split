# Sideview Server Logic

Orchestrates bi-directional Shiny reactivity between the infinite 2D
canvas and the R session. Handles field mapping (`column_mapped`),
column renaming (`column_renamed`), discrepancy calculations
(`discrepancy_check`), natural language AI prompts (`run_ai_prompt`),
RStudio script injection (`inject_script`), and RStudio console
execution (`send_console`).

## Usage

``` r
sideview_server(
  cards = list(),
  ...,
  llm_fn = sv_call_llm,
  insert_fn = sv_insert_code,
  console_fn = sv_send_to_console
)
```

## Arguments

- cards:

  A `sideview_card` object, a list of `sideview_card` objects, or
  tabular objects to be normalized.

- ...:

  Additional arguments.

- llm_fn:

  Function used to execute LLM queries (default `sv_call_llm`).

- insert_fn:

  Function used to insert code into active RStudio document (default
  `sv_insert_code`).

- console_fn:

  Function used to send code to RStudio console (default
  `sv_send_to_console`).

## Value

A Shiny server function `function(input, output, session)`.
