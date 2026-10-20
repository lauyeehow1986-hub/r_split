# Call Local Ollama or OpenAI-Compatible LLM Endpoint

Sends prompt requests to local Ollama (`http://localhost:11434`) or
OpenAI-compatible endpoints via `httr2`. Supports model selection,
customizable endpoints, API key authentication, and clean error
reporting for network or HTTP status failures.

## Usage

``` r
sv_call_llm(
  prompt,
  backend = c("ollama", "openai"),
  model = NULL,
  endpoint = NULL,
  api_key = NULL,
  timeout = 60,
  extract_code = FALSE,
  ...
)
```

## Arguments

- prompt:

  A character string or `sideview_prompt` object from `sv_build_prompt`.

- backend:

  Character string: either `"ollama"` or `"openai"`.

- model:

  Model name (e.g., `"llama3.2"`, `"llama3"`, `"gpt-4o-mini"`).

- endpoint:

  Base URL or full chat endpoint for the API.

- api_key:

  API key (for OpenAI or authenticated endpoints).

- timeout:

  Request timeout in seconds. Default 60.

- extract_code:

  Logical; if TRUE, runs
  [`sv_extract_code()`](https://lauyeehow1986-hub.github.io/r_split/reference/sv_extract_code.md)
  on the response text. Default FALSE.

- ...:

  Additional options passed to request.

## Value

Character string containing the LLM response text (or extracted code if
`extract_code = TRUE`).
