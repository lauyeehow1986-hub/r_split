# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("sv_build_schema_context summarizes single tabular card safely", {
  card <- sv_normalize(mtcars, name = "CarsData")
  schema <- sv_build_schema_context(card)

  expect_type(schema, "character")
  expect_length(schema, 1L)
  expect_true(grepl("CarsData", schema))
  expect_true(grepl("32 rows", schema, ignore.case = TRUE))
  expect_true(grepl("11 col", schema, ignore.case = TRUE))
  expect_true(grepl("mpg", schema))
  expect_true(grepl("range", schema, ignore.case = TRUE))

  # Ensure raw full dump is not leaked (mtcars has 32 rows, should not dump all row values)
  # Check that it doesn't contain a raw dataframe printout like "Mazda RX4"
  expect_false(grepl("Mazda RX4", schema))
})

test_that("sv_build_schema_context summarizes factor, character, and date columns", {
  df <- data.frame(
    category = factor(rep(c("Alpha", "Beta", "Gamma"), length.out = 100)),
    city = rep(c("Tokyo", "London", "Paris", "Berlin"), length.out = 100),
    event_date = seq(as.Date("2024-01-01"), by = "day", length.out = 100),
    score = rnorm(100, mean = 50, sd = 5),
    stringsAsFactors = FALSE
  )
  card <- sv_normalize(df, name = "Metrics")
  schema <- sv_build_schema_context(card)

  expect_true(grepl("Metrics", schema))
  expect_true(grepl("category", schema))
  expect_true(grepl("Alpha", schema))
  expect_true(grepl("event_date", schema))
  expect_true(grepl("2024-01-01", schema))
})

test_that("sv_build_schema_context handles missing values and truncated categories", {
  df <- data.frame(
    id = 1:50,
    tags = paste0("tag_", 1:50), # 50 distinct categories
    val_na = c(10, 20, NA, 40, NA, rep(NA, 45)),
    all_na = as.numeric(rep(NA, 50)),
    stringsAsFactors = FALSE
  )
  card <- sv_normalize(df, name = "TagTable")
  schema <- sv_build_schema_context(card)

  expect_true(grepl("TagTable", schema))
  expect_true(grepl("tags", schema))
  # Should truncate categories rather than dump all 50
  expect_false(grepl("tag_49", schema))
  expect_true(grepl("val_na", schema))
  expect_true(grepl("all_na", schema))
})

test_that("sv_build_schema_context handles multiple cards, empty lists, and non-tabular cards", {
  # Empty input
  expect_equal(sv_build_schema_context(list()), "")

  # Multiple cards
  c1 <- sv_normalize(data.frame(a = 1:5), name = "T1")
  c2 <- sv_normalize(data.frame(b = c("x", "y")), name = "T2")
  schema <- sv_build_schema_context(list(c1, c2))
  expect_true(grepl("T1", schema))
  expect_true(grepl("T2", schema))

  # Card with NULL data or widget
  null_card <- structure(
    list(id = "card_widget", name = "MyWidget", type = "widget", data = NULL),
    class = c("sideview_card", "list")
  )
  schema_null <- sv_build_schema_context(null_card)
  expect_true(grepl("MyWidget", schema_null))
  expect_true(grepl("widget|no tabular data", schema_null, ignore.case = TRUE))
})

test_that("sv_build_prompt formats system instructions and combines schema context", {
  prompt_info <- sv_build_prompt(
    user_prompt = "Join sales and customers on customer_id and sum amount",
    schema_context = "Table: sales (customer_id, amount)\nTable: customers (customer_id, name)"
  )

  expect_type(prompt_info, "list")
  expect_true("system_message" %in% names(prompt_info) || "system" %in% names(prompt_info))
  expect_true("user_message" %in% names(prompt_info) || "user" %in% names(prompt_info))

  sys_msg <- prompt_info$system_message %||% prompt_info$system
  usr_msg <- prompt_info$user_message %||% prompt_info$user

  # System message should instruct clean tidyverse R code in ```r blocks
  expect_true(grepl("tidyverse|dplyr", sys_msg, ignore.case = TRUE))
  expect_true(grepl("```r", sys_msg))

  # User message contains the prompt and schema
  expect_true(grepl("Join sales and customers", usr_msg))
  expect_true(grepl("customer_id", usr_msg))
})

test_that("sv_extract_code extracts code from various markdown fences and raw text", {
  # Standard ```r ... ```
  res1 <- sv_extract_code("Here is your solution:\n```r\nmtcars |> filter(mpg > 20)\n```\nEnjoy!")
  expect_equal(res1, "mtcars |> filter(mpg > 20)")

  # Uppercase ```R ... ```
  res2 <- sv_extract_code("```R\nlibrary(dplyr)\niris |> count(Species)\n```")
  expect_equal(res2, "library(dplyr)\niris |> count(Species)")

  # Generic ``` ... ```
  res3 <- sv_extract_code("```\nx <- 1:10\nmean(x)\n```")
  expect_equal(res3, "x <- 1:10\nmean(x)")

  # Multiple code fences concatenated
  res4 <- sv_extract_code("First step:\n```r\na <- 1\n```\nSecond step:\n```r\nb <- 2\n```")
  expect_equal(res4, "a <- 1\nb <- 2")

  # Raw code fallback without markdown fences
  raw_code <- "df |> mutate(z = x + y)"
  expect_equal(sv_extract_code(raw_code), raw_code)

  # Whitespace trimming
  padded <- "   \n```r\nval <- 42\n```\n\n   "
  expect_equal(sv_extract_code(padded), "val <- 42")

  # Ensure parsed expression works
  parsed <- parse(text = sv_extract_code(res1))
  expect_true(is.expression(parsed))
})

test_that("sv_call_llm constructs valid requests for Ollama backend", {
  captured_req <- NULL
  mock_ollama <- function(req) {
    captured_req <<- req
    resp_payload <- list(
      model = "llama3.2",
      message = list(role = "assistant", content = "```r\nmtcars |> select(mpg)\n```"),
      done = TRUE
    )
    httr2::response(
      status_code = 200L,
      headers = list("content-type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(resp_payload, auto_unbox = TRUE))
    )
  }

  prompt <- sv_build_prompt("Show mpg", schema_context = "Table: mtcars")

  httr2::with_mocked_responses(mock_ollama, {
    result <- sv_call_llm(
      prompt = prompt,
      backend = "ollama",
      model = "llama3.2",
      endpoint = "http://localhost:11434"
    )

    expect_type(result, "character")
    expect_true(grepl("mtcars", result))
    expect_false(is.null(captured_req))

    # Check request URL and method
    expect_true(grepl("11434", captured_req$url))
    expect_equal(captured_req$method, "POST")

    # Inspect payload sent
    expect_equal(captured_req$body$data$model, "llama3.2")
    expect_false(is.null(captured_req$body$data$messages))
    expect_false(captured_req$body$data$stream)

    # Test with extract_code = TRUE
    result_code <- sv_call_llm(
      prompt = prompt,
      backend = "ollama",
      model = "llama3.2",
      endpoint = "http://localhost:11434",
      extract_code = TRUE
    )
    expect_equal(result_code, "mtcars |> select(mpg)")
  })
})

test_that("sv_call_llm constructs valid requests for OpenAI backend", {
  captured_req <- NULL
  mock_openai <- function(req) {
    captured_req <<- req
    resp_payload <- list(
      id = "chatcmpl-123",
      choices = list(
        list(
          index = 0L,
          message = list(role = "assistant", content = "```r\ndf |> group_by(grp) |> summarize(n = n())\n```"),
          finish_reason = "stop"
        )
      )
    )
    httr2::response(
      status_code = 200L,
      headers = list("content-type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(resp_payload, auto_unbox = TRUE))
    )
  }

  prompt <- sv_build_prompt("Summarize by grp", schema_context = "Table: df (grp)")

  httr2::with_mocked_responses(mock_openai, {
    result <- sv_call_llm(
      prompt = prompt,
      backend = "openai",
      model = "gpt-4o-mini",
      endpoint = "https://api.openai.com/v1",
      api_key = "sk-test-secret-key"
    )

    expect_type(result, "character")
    expect_true(grepl("group_by", result))
    expect_false(is.null(captured_req))

    # Verify endpoint and Authorization header
    expect_true(grepl("chat/completions", captured_req$url))
    dry <- httr2::req_dry_run(captured_req, redact_headers = FALSE, quiet = TRUE)
    expect_equal(dry$headers$authorization, "Bearer sk-test-secret-key")

    # Verify JSON body
    expect_equal(captured_req$body$data$model, "gpt-4o-mini")
    expect_equal(length(captured_req$body$data$messages), 2L)
  })
})

test_that("sv_call_llm handles API errors cleanly with informative messages", {
  mock_401 <- function(req) {
    httr2::response(
      status_code = 401L,
      headers = list("content-type" = "application/json"),
      body = charToRaw('{"error": {"message": "Incorrect API key provided"}}')
    )
  }

  httr2::with_mocked_responses(mock_401, {
    expect_error(
      sv_call_llm(
        prompt = "test",
        backend = "openai",
        endpoint = "https://api.openai.com/v1",
        api_key = "invalid-key"
      ),
      "401|API key|Unauthorized"
    )
  })

  mock_500 <- function(req) {
    httr2::response(
      status_code = 500L,
      headers = list("content-type" = "application/json"),
      body = charToRaw('{"error": "Internal server error"}')
    )
  }

  httr2::with_mocked_responses(mock_500, {
    expect_error(
      sv_call_llm(
        prompt = "test",
        backend = "ollama",
        endpoint = "http://localhost:11434"
      ),
      "500|server error"
    )
  })
})
