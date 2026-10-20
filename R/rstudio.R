#' Check if RStudio API is Available
#'
#' Safely tests whether the RStudio API is running and operational in the current
#' session without raising errors in headless, testing, or CI environments.
#'
#' @return Logical scalar (`TRUE` if RStudio is running and accessible, `FALSE` otherwise).
#' @export
#' @examples
#' sv_is_rstudio_available()
sv_is_rstudio_available <- function() {
  if (!requireNamespace("rstudioapi", quietly = TRUE)) {
    return(FALSE)
  }
  tryCatch(
    isTRUE(rstudioapi::isAvailable()),
    error = function(e) FALSE
  )
}

#' Insert Generated Code into the Active RStudio Editor
#'
#' Inserts tidyverse pipelines or generated code directly into the user's active
#' document buffer at the current cursor location via `rstudioapi::insertText()`.
#' If RStudio is unavailable, running headless, or if no document is currently open,
#' falls back gracefully by returning a structured status list containing the code.
#'
#' @param code Character vector or scalar string containing the code to insert.
#'   Multiple elements are joined by newline characters.
#' @param location Optional cursor position or range for `rstudioapi::insertText()`.
#'   Defaults to `NULL` (current selection/cursor).
#' @param ... Additional arguments passed to `rstudioapi::insertText()`.
#'
#' @return A named list with:
#'   \item{success}{Logical indicating whether insertion into editor succeeded.}
#'   \item{destination}{Character `"editor"` on success, `"fallback"` on fallback/error.}
#'   \item{code}{Character string of the normalized code.}
#'   \item{message}{Character description of the result or error.}
#' @export
#' @examples
#' res <- sv_insert_code("library(dplyr)")
sv_insert_code <- function(code, location = NULL, ...) {
  if (is.null(code) || length(code) == 0) {
    code_str <- ""
  } else {
    valid_lines <- code[!is.na(code)]
    code_str <- paste(as.character(valid_lines), collapse = "\n")
  }

  if (!sv_is_rstudio_available()) {
    return(list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = "RStudio is not available."
    ))
  }

  # First attempt to resolve active document via getSourceEditorContext
  # (handles Shiny Gadgets and console focus), then fall back to getActiveDocumentContext
  ctx <- tryCatch({
    c_edit <- rstudioapi::getSourceEditorContext()
    if (!is.null(c_edit) && !is.null(c_edit$id) && nzchar(c_edit$id) && c_edit$id != "#console") {
      c_edit
    } else {
      NULL
    }
  }, error = function(e) NULL)

  if (is.null(ctx)) {
    ctx <- tryCatch({
      c_act <- rstudioapi::getActiveDocumentContext()
      if (!is.null(c_act) && !is.null(c_act$id) && nzchar(c_act$id) && c_act$id != "#console") {
        c_act
      } else {
        NULL
      }
    }, error = function(e) NULL)
  }

  if (is.null(ctx)) {
    return(list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = "No active document open in RStudio."
    ))
  }

  tryCatch({
    insert_args <- list(text = code_str, ...)
    if (!is.null(location)) {
      insert_args$location <- location
    }
    if (!"id" %in% names(insert_args) && !is.null(ctx$id)) {
      insert_args$id <- ctx$id
    }
    do.call(rstudioapi::insertText, insert_args)

    list(
      success = TRUE,
      destination = "editor",
      code = code_str,
      message = "Code successfully inserted into active RStudio document."
    )
  }, error = function(e) {
    list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = paste0("Failed to insert code into document: ", conditionMessage(e))
    )
  })
}

#' Send Generated Code to the RStudio Console
#'
#' Sends R code to the RStudio console for immediate evaluation or user inspection.
#' Falls back gracefully without crashing if RStudio is unavailable or running in
#' a headless environment.
#'
#' @param code Character vector or scalar string containing the code to execute.
#'   Multiple elements are joined by newline characters.
#' @param execute Logical indicating whether to execute the code immediately (`TRUE`)
#'   or simply populate the console line without executing (`FALSE`). Default `TRUE`.
#' @param ... Additional arguments passed to `rstudioapi::sendToConsole()`.
#'
#' @return A named list with:
#'   \item{success}{Logical indicating whether console transmission succeeded.}
#'   \item{destination}{Character `"console"` on success, `"fallback"` on fallback/error.}
#'   \item{code}{Character string of the normalized code.}
#'   \item{message}{Character description of the result or error.}
#' @export
#' @examples
#' res <- sv_send_to_console("1 + 1", execute = FALSE)
sv_send_to_console <- function(code, execute = TRUE, ...) {
  if (is.null(code) || length(code) == 0) {
    code_str <- ""
  } else {
    valid_lines <- code[!is.na(code)]
    code_str <- paste(as.character(valid_lines), collapse = "\n")
  }

  execute <- isTRUE(execute)

  if (!sv_is_rstudio_available()) {
    return(list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = "RStudio is not available."
    ))
  }

  tryCatch({
    rstudioapi::sendToConsole(code = code_str, execute = execute, ...)
    list(
      success = TRUE,
      destination = "console",
      code = code_str,
      message = "Code successfully sent to RStudio console."
    )
  }, error = function(e) {
    list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = paste0("Failed to send code to console: ", conditionMessage(e))
    )
  })
}
