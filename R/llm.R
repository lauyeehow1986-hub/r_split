# Helper operator for null default
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Build a Privacy-Safe Schema Context from Sideview Cards
#'
#' Summarizes the metadata of sideview cards (table names, dimensions, column
#' names, types, value ranges for numerics/dates, sample levels for factors, and
#' unique samples for characters) without leaking full raw row data or records.
#' Non-tabular widget cards and NULL data are handled safely.
#'
#' @param cards A `sideview_card`, a list of `sideview_card`s, or tabular data.
#' @param max_categories Maximum sample unique categories to report for categorical columns. Default is 5.
#'
#' @return A character string containing the privacy-safe schema summary.
#' @export
sv_build_schema_context <- function(cards, max_categories = 5L) {
  if (is.null(cards) || (is.list(cards) && length(cards) == 0L)) {
    return("")
  }

  if (inherits(cards, "sideview_card") || is.data.frame(cards)) {
    cards <- list(cards)
  }

  card_summaries <- character(0)

  for (card in cards) {
    if (is.data.frame(card) && !inherits(card, "sideview_card")) {
      card <- sv_normalize(card)
    }

    if (!inherits(card, "sideview_card")) {
      next
    }

    c_name <- card$name %||% "Table"
    c_id <- card$id %||% "card"
    c_type <- card$type %||% "grid"
    df <- card$data

    if (is.null(df) || !is.data.frame(df)) {
      summary_txt <- sprintf(
        "Table: %s (id: %s, type: %s - no tabular data available)",
        c_name, c_id, c_type
      )
      card_summaries <- c(card_summaries, summary_txt)
      next
    }

    nr <- nrow(df)
    nc <- ncol(df)

    lines <- c(
      sprintf("Table: %s (id: %s)", c_name, c_id),
      sprintf("Dimensions: %d rows x %d columns", nr, nc),
      "Columns:"
    )

    col_names <- colnames(df)
    if (length(col_names) == 0L) {
      lines <- c(lines, "  (No columns)")
    } else {
      for (col in col_names) {
        val <- df[[col]]
        col_type <- class(val)[1]

        detail <- ""
        if (is.numeric(val)) {
          non_na <- val[!is.na(val)]
          if (length(non_na) == 0L) {
            detail <- "[all NA]"
          } else {
            min_v <- signif(min(non_na), 4)
            max_v <- signif(max(non_na), 4)
            detail <- sprintf("[range: %s to %s]", min_v, max_v)
            na_cnt <- sum(is.na(val))
            if (na_cnt > 0L) {
              detail <- paste0(detail, sprintf(" (%d NAs)", na_cnt))
            }
          }
        } else if (inherits(val, "Date") || inherits(val, "POSIXt")) {
          non_na <- val[!is.na(val)]
          if (length(non_na) == 0L) {
            detail <- "[all NA]"
          } else {
            min_v <- format(min(non_na))
            max_v <- format(max(non_na))
            detail <- sprintf("[range: %s to %s]", min_v, max_v)
            na_cnt <- sum(is.na(val))
            if (na_cnt > 0L) {
              detail <- paste0(detail, sprintf(" (%d NAs)", na_cnt))
            }
          }
        } else if (is.factor(val)) {
          levs <- levels(val)
          n_levs <- length(levs)
          sample_n <- min(as.integer(max_categories), n_levs)
          sample_levs <- levs[seq_len(sample_n)]
          samp_str <- paste(sample_levs, collapse = ", ")
          if (n_levs > sample_n) {
            samp_str <- paste0(samp_str, sprintf(", ... (%d total levels)", n_levs))
          }
          detail <- sprintf("[categories: %s]", samp_str)
        } else if (is.character(val)) {
          non_na <- unique(val[!is.na(val)])
          n_uniq <- length(non_na)
          sample_n <- min(as.integer(max_categories), n_uniq)
          sample_vals <- non_na[seq_len(sample_n)]
          samp_str <- paste(sample_vals, collapse = ", ")
          if (n_uniq > sample_n) {
            samp_str <- paste0(samp_str, sprintf(", ... (%d unique values)", n_uniq))
          }
          detail <- sprintf("[categories: %s]", samp_str)
        } else if (is.logical(val)) {
          detail <- sprintf(
            "[logical: %d TRUE, %d FALSE, %d NA]",
            sum(val == TRUE, na.rm = TRUE),
            sum(val == FALSE, na.rm = TRUE),
            sum(is.na(val))
          )
        } else {
          detail <- sprintf("[%s]", col_type)
        }

        lines <- c(lines, sprintf("  - %s (%s): %s", col, col_type, detail))
      }
    }

    card_summaries <- c(card_summaries, paste(lines, collapse = "\n"))
  }

  paste(card_summaries, collapse = "\n\n")
}

#' Build Structured Prompt for Tidyverse LLM Code Generation
#'
#' Formats system instructions emphasizing pure, executable tidyverse R code
#' enclosed in markdown code fences (` ```r ... ``` `) and packages user task
#' description alongside privacy-safe table schemas.
#'
#' @param user_prompt Natural language description of desired data transformation.
#' @param schema_context Optional privacy-safe schema string built via `sv_build_schema_context`.
#'
#' @return A list of class `sideview_prompt` containing `system_message`, `user_message`, and `prompt`.
#' @export
sv_build_prompt <- function(user_prompt, schema_context = NULL) {
  system_message <- paste(
    "You are an expert R and tidyverse data transformation assistant.",
    "Your task is to generate clean, robust, and executable R code using modern tidyverse packages (e.g. dplyr, tidyr, purrr, ggplot2).",
    "Follow these strict rules:",
    "1. Return ONLY executable R code enclosed in a ```r ... ``` code block.",
    "2. Use modern native pipe |> or dplyr pipe %>% consistently.",
    "3. Refer only to the tables and column names provided in the schema context.",
    "4. Do NOT output conversational chit-chat, pleasantries, or preamble outside the code block.",
    "5. If comments are needed, write them as R code comments (#) inside the code block.",
    sep = "\n"
  )

  user_parts <- character(0)
  if (!is.null(schema_context) && nzchar(trimws(schema_context))) {
    user_parts <- c(user_parts, "Available table schemas:", schema_context, "")
  }
  user_parts <- c(user_parts, paste("Task:", user_prompt))
  user_message <- paste(user_parts, collapse = "\n")

  full_prompt <- paste(system_message, "\n\n", user_message, sep = "")

  structure(
    list(
      system_message = system_message,
      user_message = user_message,
      system = system_message,
      user = user_message,
      prompt = full_prompt
    ),
    class = c("sideview_prompt", "list")
  )
}

#' Extract Executable R Code from LLM Response Text
#'
#' Parses code fence blocks (` ```r ... ``` `, ` ```R ... ``` `, ` ``` ... ``` `)
#' out of LLM responses. If multiple fences exist, concatenates them. If no fence
#' is found, falls back to the trimmed raw text. Strips extraneous whitespace
#' and returns valid R code.
#'
#' @param response_text Character vector containing the LLM response text.
#'
#' @return A character string of extracted R code.
#' @export
sv_extract_code <- function(response_text) {
  if (is.null(response_text) || length(response_text) == 0L) {
    return("")
  }

  text <- paste(response_text, collapse = "\n")

  # Regex pattern to match markdown code blocks
  pattern <- "(?s)```(?:[rR]|\\{r\\})?\\s*\\r?\\n?(.*?)\\r?\\n?```"
  matches <- gregexpr(pattern, text, perl = TRUE)

  extracted <- character(0)
  reg_starts <- matches[[1]]

  if (length(reg_starts) > 0L && reg_starts[1] != -1L) {
    match_lens <- attr(matches[[1]], "match.length")
    for (i in seq_along(reg_starts)) {
      block_str <- substr(text, reg_starts[i], reg_starts[i] + match_lens[i] - 1L)
      # Strip opening fence
      inner <- sub("^```(?:[rR]|\\{r\\})?\\s*\\r?\\n?", "", block_str, perl = TRUE)
      # Strip closing fence
      inner <- sub("\\r?\\n?```$", "", inner, perl = TRUE)
      extracted <- c(extracted, trimws(inner))
    }
  }

  if (length(extracted) > 0L) {
    code <- paste(extracted[nzchar(extracted)], collapse = "\n")
  } else {
    code <- trimws(text)
  }

  trimws(code)
}

#' Call Local Ollama or OpenAI-Compatible LLM Endpoint
#'
#' Sends prompt requests to local Ollama (`http://localhost:11434`) or OpenAI-compatible
#' endpoints via `httr2`. Supports model selection, customizable endpoints, API key authentication,
#' and clean error reporting for network or HTTP status failures.
#'
#' @param prompt A character string or `sideview_prompt` object from `sv_build_prompt`.
#' @param backend Character string: either `"ollama"` or `"openai"`.
#' @param model Model name (e.g., `"llama3.2"`, `"llama3"`, `"gpt-4o-mini"`).
#' @param endpoint Base URL or full chat endpoint for the API.
#' @param api_key API key (for OpenAI or authenticated endpoints).
#' @param timeout Request timeout in seconds. Default 60.
#' @param extract_code Logical; if TRUE, runs `sv_extract_code()` on the response text. Default FALSE.
#' @param ... Additional options passed to request.
#'
#' @return Character string containing the LLM response text (or extracted code if `extract_code = TRUE`).
#' @export
sv_call_llm <- function(prompt,
                        backend = c("ollama", "openai"),
                        model = NULL,
                        endpoint = NULL,
                        api_key = NULL,
                        timeout = 60,
                        extract_code = FALSE,
                        ...) {
  backend <- match.arg(backend)

  # Format prompt into system and user messages
  if (inherits(prompt, "sideview_prompt") || is.list(prompt)) {
    sys_msg <- prompt$system_message %||% prompt$system %||% ""
    usr_msg <- prompt$user_message %||% prompt$user %||% prompt$prompt %||% ""
  } else {
    p_obj <- sv_build_prompt(as.character(prompt))
    sys_msg <- p_obj$system_message
    usr_msg <- p_obj$user_message
  }

  # Endpoint and model defaults
  if (backend == "ollama") {
    endpoint <- endpoint %||% Sys.getenv("OLLAMA_HOST", "http://localhost:11434")
    model <- model %||% Sys.getenv("SIDEVIEW_OLLAMA_MODEL", "llama3.2")
    if (!grepl("/api/(chat|generate)$", endpoint)) {
      endpoint <- paste0(sub("/+$", "", endpoint), "/api/chat")
    }
  } else {
    endpoint <- endpoint %||% Sys.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
    model <- model %||% Sys.getenv("SIDEVIEW_OPENAI_MODEL", "gpt-4o-mini")
    api_key <- api_key %||% Sys.getenv("OPENAI_API_KEY", "")
    if (!grepl("/chat/completions$", endpoint)) {
      endpoint <- paste0(sub("/+$", "", endpoint), "/chat/completions")
    }
  }

  # Build messages array
  messages <- list()
  if (nzchar(sys_msg)) {
    messages <- c(messages, list(list(role = "system", content = sys_msg)))
  }
  if (nzchar(usr_msg)) {
    messages <- c(messages, list(list(role = "user", content = usr_msg)))
  }

  payload <- list(
    model = model,
    messages = messages
  )

  if (backend == "ollama") {
    payload$stream <- FALSE
  }

  req <- httr2::request(endpoint)
  req <- httr2::req_method(req, "POST")
  req <- httr2::req_timeout(req, timeout)
  req <- httr2::req_headers(req, "Content-Type" = "application/json")

  if (backend == "openai" && !is.null(api_key) && nzchar(api_key)) {
    req <- httr2::req_headers(req, "Authorization" = paste("Bearer", api_key))
  }

  req <- httr2::req_body_json(req, payload)

  # Execute request with error trapping
  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) {
      if (inherits(e, "httr2_http")) {
        err_resp <- e$resp
        status <- httr2::resp_status(err_resp)
        body_txt <- tryCatch(httr2::resp_body_string(err_resp), error = function(e2) "")
        err_msg <- tryCatch({
          err_json <- jsonlite::fromJSON(body_txt)
          if (is.list(err_json$error) && !is.null(err_json$error$message)) {
            err_json$error$message
          } else if (is.character(err_json$error)) {
            err_json$error
          } else if (!is.null(err_json$message)) {
            err_json$message
          } else {
            body_txt
          }
        }, error = function(e2) body_txt)
        stop(sprintf("Sideview LLM API error (%d): %s", status, err_msg), call. = FALSE)
      }
      stop(sprintf("Sideview LLM connection failed (%s at %s): %s", backend, endpoint, e$message), call. = FALSE)
    }
  )

  # Verify status
  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    body_txt <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
    err_msg <- tryCatch({
      err_json <- jsonlite::fromJSON(body_txt)
      if (is.list(err_json$error) && !is.null(err_json$error$message)) {
        err_json$error$message
      } else if (is.character(err_json$error)) {
        err_json$error
      } else if (!is.null(err_json$message)) {
        err_json$message
      } else {
        body_txt
      }
    }, error = function(e) body_txt)
    stop(sprintf("Sideview LLM API error (%d): %s", status, err_msg), call. = FALSE)
  }

  # Parse response body
  resp_json <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) {
      stop("Failed to parse JSON response from LLM server: ", e$message, call. = FALSE)
    }
  )

  content <- NULL
  if (!is.null(resp_json$choices) && length(resp_json$choices) > 0L) {
    content <- resp_json$choices[[1]]$message$content
  } else if (!is.null(resp_json$message$content)) {
    content <- resp_json$message$content
  } else if (!is.null(resp_json$response)) {
    content <- resp_json$response
  }

  if (is.null(content)) {
    content <- ""
  }

  if (extract_code) {
    content <- sv_extract_code(content)
  }

  content
}
