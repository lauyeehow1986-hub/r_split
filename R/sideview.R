#' Find Tabular Data Objects in an Environment
#'
#' Scans an environment for tabular objects, including `data.frame`, `tibble`,
#' `matrix`, `table`, `gt`, `flextable`, and `sideview_card` objects.
#'
#' @param env Environment to scan (defaults to `parent.frame()`).
#'
#' @return A named list of tabular objects found in the environment.
#' @export
sv_find_tables <- function(env = parent.frame()) {
  if (is.null(env) || !is.environment(env)) {
    return(list())
  }
  
  obj_names <- ls(envir = env, all.names = FALSE)
  tables <- list()
  
  for (nm in obj_names) {
    val <- tryCatch(get(nm, envir = env), error = function(e) NULL)
    if (is.null(val)) next
    
    is_tabular <- is.data.frame(val) ||
      inherits(val, c("tbl_df", "gt_tbl", "flextable", "table", "matrix", "sideview_card"))
    
    if (is_tabular) {
      tables[[nm]] <- val
    }
  }
  
  tables
}

#' Multi-Table 2D Infinite Canvas Interactive Gadget
#'
#' Launches an interactive Shiny gadget containing an infinite 2D canvas with
#' mouse-wheel zoom, pan, draggable table cards, interactive column mapping,
#' discrepancy recoding, and LLM-assisted tidyverse code generation.
#'
#' @param ... Arbitrary table objects (`data.frame`, `tibble`, `matrix`,
#'   `table`, `gt`, `flextable`, `htmlwidgets`), named or unnamed.
#' @param title Title for the gadget viewer.
#' @param viewer Shiny viewer gadget display mode (e.g. `shiny::paneViewer()`,
#'   `shiny::dialogViewer()`, or `shiny::browserViewer()`).
#' @param run Logical; if `TRUE`, launches the interactive gadget via
#'   `shiny::runGadget()`. If `FALSE`, returns the `shiny.appobj` definition
#'   without launching (useful for testing or embedding). Defaults to `interactive()`.
#'
#' @return If `run = TRUE`, returns the result of `shiny::runGadget()`.
#'   If `run = FALSE`, returns a `shiny.appobj` with the normalized cards attached.
#' @export
#' @examples
#' if (interactive()) {
#'   sideview(mtcars, iris)
#' }
sideview <- function(...,
                     title = "Sideview Canvas",
                     viewer = if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
                       shiny::dialogViewer("Sideview Canvas", width = 1150, height = 750)
                     } else {
                       shiny::paneViewer(minHeight = 500)
                     },
                     run = interactive()) {
  # Capture expressions and evaluate items
  dots_exprs <- as.list(substitute(list(...))[-1])
  dots_vals <- list(...)
  
  # Flatten if a single list was passed
  if (length(dots_vals) == 1 && is.list(dots_vals[[1]]) &&
      !is.data.frame(dots_vals[[1]]) && !inherits(dots_vals[[1]], "sideview_card")) {
    dots_vals <- dots_vals[[1]]
    dots_exprs <- as.list(names(dots_vals))
  }
  
  card_list <- list()
  for (i in seq_along(dots_vals)) {
    val <- dots_vals[[i]]
    if (is.null(val)) next
    
    # Determine table name
    nm <- names(dots_vals)[i]
    if (is.null(nm) || !nzchar(nm)) {
      if (i <= length(dots_exprs)) {
        dep <- deparse(dots_exprs[[i]])[1]
        # Clean expression to a simple identifier if possible
        dep <- sub("^.*\\$", "", dep)
        dep <- make.names(dep)
        nm <- dep
      } else {
        nm <- paste0("Table_", i)
      }
    }
    
    card <- if (inherits(val, "sideview_card")) {
      val
    } else {
      tryCatch(sv_normalize(val, name = nm), error = function(e) NULL)
    }
    
    if (!is.null(card)) {
      card_list[[length(card_list) + 1]] <- card
    }
  }
  
  # Build Shiny application object
  ui <- sideview_ui(card_list, title = title)
  server <- sideview_server(card_list)
  app <- shiny::shinyApp(ui = ui, server = server)
  
  # Attach cards metadata
  attr(app, "cards") <- card_list
  app$cards <- card_list
  
  if (isTRUE(run)) {
    shiny::runGadget(app, viewer = viewer)
  } else {
    app
  }
}

#' RStudio Addin for Sideview
#'
#' Automatically discovers tabular datasets in the user's active environment
#' and launches the Sideview interactive multi-table canvas gadget.
#'
#' @param env Environment to search for tables (defaults to `.GlobalEnv`).
#' @param viewer Shiny viewer gadget display mode (default `shiny::paneViewer()`).
#' @param run Logical indicating whether to execute the gadget. Default `interactive()`.
#'
#' @return Result of `sideview(...)`.
#' @export
sideview_addin <- function(env = .GlobalEnv,
                           viewer = if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
                       shiny::dialogViewer("Sideview Canvas", width = 1150, height = 750)
                     } else {
                       shiny::paneViewer(minHeight = 500)
                     },
                           run = interactive()) {
  tables <- sv_find_tables(env)
  
  if (length(tables) == 0) {
    # If no tables found in environment, provide sample datasets
    message("Sideview Addin: No tabular objects found in environment; loading sample data (mtcars, iris).")
    tables <- list(
      mtcars = datasets::mtcars,
      iris = datasets::iris
    )
  }
  
  sideview(tables, title = "Sideview Canvas", viewer = viewer, run = run)
}
