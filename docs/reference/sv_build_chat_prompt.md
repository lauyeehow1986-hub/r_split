# Build Structured Multi-Turn Prompt for Conversational Copilot

Formats a multi-turn conversational prompt for the Sideview AI Copilot
drawer. Preserves database/table schema context, active pipeline R code,
and previous dialogue turns (user/assistant). Instructs the model to
output updated executable tidyverse R code within code fences.

## Usage

``` r
sv_build_chat_prompt(
  user_message,
  history = list(),
  current_code = NULL,
  schema_context = NULL
)
```

## Arguments

- user_message:

  Natural language query or instruction from the user.

- history:

  A list of previous conversation turns, where each turn is a list
  containing `role` ("user" or "assistant") and `content` (or
  `text`/`message`).

- current_code:

  Optional character string containing the currently active pipeline
  code in the drawer.

- schema_context:

  Optional privacy-safe schema string built via
  `sv_build_schema_context`.

## Value

A list of class `c("sideview_chat_prompt", "sideview_prompt", "list")`
containing `system_message`, `user_message`, `history`, `messages`, and
`prompt`.
