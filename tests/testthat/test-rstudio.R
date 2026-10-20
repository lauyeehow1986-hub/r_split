# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

test_that("sv_is_rstudio_available returns a clean boolean in headless mode", {
  res <- sv_is_rstudio_available()
  expect_type(res, "logical")
  expect_length(res, 1)
  # In standard test environment, RStudio is not running
  expect_false(res)
})

test_that("sv_is_rstudio_available respects mocked rstudioapi states", {
  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    .package = "rstudioapi",
    code = {
      expect_true(sv_is_rstudio_available())
    }
  )

  testthat::with_mocked_bindings(
    isAvailable = function(...) FALSE,
    .package = "rstudioapi",
    code = {
      expect_false(sv_is_rstudio_available())
    }
  )

  testthat::with_mocked_bindings(
    isAvailable = function(...) stop("RStudio API connection crashed"),
    .package = "rstudioapi",
    code = {
      expect_false(sv_is_rstudio_available())
    }
  )
})

test_that("sv_insert_code falls back gracefully when RStudio is unavailable", {
  testthat::with_mocked_bindings(
    isAvailable = function(...) FALSE,
    .package = "rstudioapi",
    code = {
      res <- sv_insert_code("df %>% mutate(x = 1)")
      expect_type(res, "list")
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
      expect_equal(res$code, "df %>% mutate(x = 1)")
      expect_match(res$message, "not available", ignore.case = TRUE)
    }
  )
})

test_that("sv_insert_code calls rstudioapi::insertText when available with active document", {
  inserted_text <- NULL
  called <- FALSE

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "doc123", path = "script.R"),
    insertText = function(text, ...) {
      called <<- TRUE
      inserted_text <<- text
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      code_to_insert <- "df %>% filter(!is.na(val))"
      res <- sv_insert_code(code_to_insert)

      expect_true(called)
      expect_equal(inserted_text, code_to_insert)
      expect_type(res, "list")
      expect_true(res$success)
      expect_equal(res$destination, "editor")
      expect_equal(res$code, code_to_insert)
      expect_match(res$message, "inserted", ignore.case = TRUE)
    }
  )
})

test_that("sv_insert_code falls back when available but no active document is open", {
  called_insert <- FALSE

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "", path = ""),
    insertText = function(...) { called_insert <<- TRUE },
    .package = "rstudioapi",
    code = {
      res <- sv_insert_code("df %>% select(1:2)")
      expect_false(called_insert)
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
      expect_match(res$message, "No active document", ignore.case = TRUE)
    }
  )

  # Also test when getActiveDocumentContext returns NULL or raises error
  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) stop("No active document available"),
    insertText = function(...) { called_insert <<- TRUE },
    .package = "rstudioapi",
    code = {
      res <- sv_insert_code("df %>% select(1:2)")
      expect_false(called_insert)
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
    }
  )
})

test_that("sv_insert_code handles multiline code vectors and strings", {
  inserted_text <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "doc_ml"),
    insertText = function(text, ...) {
      inserted_text <<- text
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      lines <- c("# Step 1: Filter", "df <- df %>%", "  filter(a > 0)")
      res <- sv_insert_code(lines)

      expect_true(res$success)
      expected <- paste(lines, collapse = "\n")
      expect_equal(inserted_text, expected)
      expect_equal(res$code, expected)
    }
  )
})

test_that("sv_insert_code handles empty code strings and NULL gracefully", {
  inserted_text <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "doc_empty"),
    insertText = function(text, ...) {
      inserted_text <<- text
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      res_empty <- sv_insert_code("")
      expect_true(res_empty$success)
      expect_equal(res_empty$code, "")
      expect_equal(inserted_text, "")

      res_null <- sv_insert_code(NULL)
      expect_true(res_null$success)
      expect_equal(res_null$code, "")
      expect_equal(inserted_text, "")

      res_char0 <- sv_insert_code(character(0))
      expect_true(res_char0$success)
      expect_equal(res_char0$code, "")
      expect_equal(inserted_text, "")
    }
  )
})

test_that("sv_insert_code handles comments and special characters", {
  inserted_text <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "doc_comments"),
    insertText = function(text, ...) {
      inserted_text <<- text
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      snippet <- "# Pipeline with $ and quotes\ndf$`col name` <- \"test\"\n# Final comment"
      res <- sv_insert_code(snippet)

      expect_true(res$success)
      expect_equal(inserted_text, snippet)
      expect_equal(res$code, snippet)
    }
  )
})

test_that("sv_insert_code catches errors thrown inside insertText", {
  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "doc_err"),
    insertText = function(...) stop("Failed to lock document buffer"),
    .package = "rstudioapi",
    code = {
      res <- sv_insert_code("df %>% head()")
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
      expect_match(res$message, "Failed to lock document buffer")
    }
  )
})

test_that("sv_send_to_console falls back gracefully when RStudio is unavailable", {
  testthat::with_mocked_bindings(
    isAvailable = function(...) FALSE,
    .package = "rstudioapi",
    code = {
      res <- sv_send_to_console("print('hello')")
      expect_type(res, "list")
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
      expect_equal(res$code, "print('hello')")
      expect_match(res$message, "not available", ignore.case = TRUE)
    }
  )
})

test_that("sv_send_to_console calls rstudioapi::sendToConsole when available", {
  sent_code <- NULL
  sent_exec <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    sendToConsole = function(code, execute = TRUE, ...) {
      sent_code <<- code
      sent_exec <<- execute
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      # Default execute = TRUE
      res <- sv_send_to_console("summary(mtcars)")
      expect_true(res$success)
      expect_equal(res$destination, "console")
      expect_equal(sent_code, "summary(mtcars)")
      expect_true(sent_exec)

      # Explicit execute = FALSE
      res2 <- sv_send_to_console("summary(iris)", execute = FALSE)
      expect_true(res2$success)
      expect_equal(sent_code, "summary(iris)")
      expect_false(sent_exec)
    }
  )
})

test_that("sv_send_to_console handles multiline code vectors and empty inputs", {
  sent_code <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    sendToConsole = function(code, ...) {
      sent_code <<- code
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      lines <- c("x <- 1:10", "mean(x)")
      res <- sv_send_to_console(lines)
      expect_true(res$success)
      expect_equal(sent_code, "x <- 1:10\nmean(x)")

      res_empty <- sv_send_to_console("")
      expect_true(res_empty$success)
      expect_equal(sent_code, "")

      res_null <- sv_send_to_console(NULL)
      expect_true(res_null$success)
      expect_equal(sent_code, "")
    }
  )
})

test_that("sv_send_to_console catches errors thrown inside sendToConsole", {
  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    sendToConsole = function(...) stop("R console busy or unresponsive"),
    .package = "rstudioapi",
    code = {
      res <- sv_send_to_console("1 + 1")
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
      expect_match(res$message, "busy or unresponsive")
    }
  )
})

test_that("sv_insert_code supports explicit location and document id via getSourceEditorContext", {
  passed_loc <- NULL
  passed_text <- NULL
  passed_id <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getSourceEditorContext = function(...) list(id = "doc_source_1", path = "script.R"),
    getActiveDocumentContext = function(...) list(id = "#console"),
    insertText = function(location = NULL, text = NULL, id = NULL, ...) {
      passed_loc <<- location
      passed_text <<- text
      passed_id <<- id
      invisible(NULL)
    },
    .package = "rstudioapi",
    code = {
      res <- sv_insert_code(c("x <- 1", NA, "y <- 2"), location = c(5, 1))
      expect_true(res$success)
      expect_equal(passed_loc, c(5, 1))
      expect_equal(passed_text, "x <- 1\ny <- 2")
      expect_equal(passed_id, "doc_source_1")
    }
  )
})

test_that("sv_insert_code handles #console gracefully when no source editor exists", {
  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getSourceEditorContext = function(...) list(id = "#console"),
    getActiveDocumentContext = function(...) list(id = "#console"),
    .package = "rstudioapi",
    code = {
      res <- sv_insert_code("df %>% head()")
      expect_false(res$success)
      expect_equal(res$destination, "fallback")
      expect_match(res$message, "No active document", ignore.case = TRUE)
    }
  )
})
