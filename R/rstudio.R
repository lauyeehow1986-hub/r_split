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
    code_str <- paste(as.character(code), collapse = "\n")
  }

  if (!sv_is_rstudio_available()) {
    return(list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = "RStudio is not available."
    ))
  }

  has_active_doc <- tryCatch({
    ctx <- rstudioapi::getActiveDocumentContext()
    !is.null(ctx) && !is.null(ctx$id) && nzchar(ctx$id) && ctx$id != "#console"
  }, error = function(e) FALSE)

  if (!has_active_doc) {
    return(list(
      success = FALSE,
      destination = "fallback",
      code = code_str,
      message = "No active document open in RStudio."
    ))
  }

  tryCatch({
    if (is.null(location)) {
      rstudioapi::insertText(text = code_str, ...)
    } else {
      rstudioapi::insertText(location = location, text = code_str, ...)
    }
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
    code_str <- paste(as.character(code), collapse = "\n")
  }

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
