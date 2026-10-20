# Package index

## Interactive Canvas & Gadget

Launch the interactive side-by-side multi-table canvas in RStudio or
standalone.

- [`sideview()`](https://lauyeehow1986-hub.github.io/r_split/reference/sideview.md)
  : Multi-Table 2D Infinite Canvas Interactive Gadget
- [`sideview_addin()`](https://lauyeehow1986-hub.github.io/r_split/reference/sideview_addin.md)
  : RStudio Addin for Sideview
- [`sideview_ui()`](https://lauyeehow1986-hub.github.io/r_split/reference/sideview_ui.md)
  : Sideview User Interface
- [`sideview_server()`](https://lauyeehow1986-hub.github.io/r_split/reference/sideview_server.md)
  : Sideview Server Logic
- [`sv_find_tables()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_find_tables.md)
  : Find Tabular Data Objects in an Environment

## Standalone HTMLWidget & Export

Export interactive canvases to self-contained, portable HTML reports or
embed in Shiny.

- [`sideview_widget()`](https://lauyeehow1986-hub.github.io/r_split/reference/sideview_widget.md)
  : Create a Standalone Sideview HTMLWidget
- [`save_sideview()`](https://lauyeehow1986-hub.github.io/r_split/reference/save_sideview.md)
  : Save Sideview Widget to a Standalone HTML File
- [`sideviewOutput()`](https://lauyeehow1986-hub.github.io/r_split/reference/sideviewOutput.md)
  : Shiny Output Container for Sideview Widget
- [`renderSideview()`](https://lauyeehow1986-hub.github.io/r_split/reference/renderSideview.md)
  : Shiny Render Function for Sideview Widget

## Tidyverse Code Generation Engine

Generate reproducible dplyr and forcats pipelines from visual canvas
interactions.

- [`sv_code_join()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_code_join.md)
  : Generate tidyverse Code for Relational Table Joins
- [`sv_code_rename()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_code_rename.md)
  : Generate tidyverse Code for Column Renaming
- [`sv_code_mutate()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_code_mutate.md)
  : Generate tidyverse Code for Column Mutation
- [`sv_code_filter()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_code_filter.md)
  : Generate tidyverse Code for Filtering Rows
- [`sv_code_select()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_code_select.md)
  : Generate tidyverse Code for Selecting Columns
- [`sv_escape_ident()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_escape_ident.md)
  : Escape R Identifiers with Backticks If Non-Syntactic

## Categorical Discrepancies & Recoding

Detect fuzzy string mismatches and generate case_match or fct_recode
pipelines.

- [`sv_detect_discrepancies()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_detect_discrepancies.md)
  : Detect Exact Matches, Discrepancies, and Fuzzy Near-Matches
- [`sv_code_recode()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_code_recode.md)
  : Generate tidyverse Code for Categorical Recoding and Discrepancy
  Crosswalks

## Local Ollama & OpenAI LLM Engine

Synthesize privacy-safe schema contexts and generate tidyverse code from
natural language prompts.

- [`sv_build_schema_context()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_build_schema_context.md)
  : Build a Privacy-Safe Schema Context from Sideview Cards
- [`sv_build_prompt()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_build_prompt.md)
  : Build Structured Prompt for Tidyverse LLM Code Generation
- [`sv_call_llm()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_call_llm.md)
  : Call Local Ollama or OpenAI-Compatible LLM Endpoint
- [`sv_extract_code()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_extract_code.md)
  : Extract Executable R Code from LLM Response Text

## RStudio API & Environment Bridge

Direct 1-click insertion into active RStudio script editor buffers and
console execution.

- [`sv_is_rstudio_available()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_is_rstudio_available.md)
  : Check if RStudio API is Available
- [`sv_insert_code()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_insert_code.md)
  : Insert Generated Code into the Active RStudio Editor
- [`sv_send_to_console()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_send_to_console.md)
  : Send Generated Code to the RStudio Console

## Universal S3 Normalization

Convert heterogeneous tabular objects into standardized sideview cards.

- [`sv_normalize()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_normalize.md)
  : Universal Normalization Engine for Sideview Cards
