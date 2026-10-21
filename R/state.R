`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Create a New Sideview Canvas State Object
#'
#' Constructs a structured `sideview_state` object containing canvas transform,
#' card configurations, table join connections, and pipeline script state.
#'
#' @param version Character string representing state schema version (default `"0.2.0"`).
#' @param canvas Named list containing canvas settings: `zoom` (numeric), `pan_x` (numeric), `pan_y` (numeric).
#' @param cards List of card state objects (each specifying `id`, `name`, `x`, `y`, `width`, `height`, `sorts`, `filters`).
#' @param connections List of join connection objects (each specifying `from_table`, `from_col`, `to_table`, `to_col`, `join_type`).
#' @param pipeline Named list containing `code` (character) and `active_tab` (character).
#'
#' @return An object of class `c("sideview_state", "list")`.
#' @export
#' @examples
#' st <- new_sideview_state()
#' print(st)
new_sideview_state <- function(version = "0.2.0",
                               canvas = list(zoom = 1, pan_x = 0, pan_y = 0),
                               cards = list(),
                               connections = list(),
                               pipeline = list(code = "", active_tab = "pipeline")) {
  state <- list(
    version = as.character(version),
    canvas = canvas,
    cards = cards,
    connections = connections,
    pipeline = pipeline
  )
  class(state) <- c("sideview_state", "list")
  state
}

#' Save Canvas State to File
#'
#' Serializes the active Sideview canvas state (cards, positions, filters, connections,
#' and pipeline code) to either `.json` or `.rds` format.
#'
#' @param state A `sideview_state` object or structured state list.
#' @param file Path to the destination file.
#' @param format Optional format specification (`"json"` or `"rds"`). If `NULL` (default),
#'   the format is inferred from the file extension (`.json` or `.rds`).
#'
#' @return Invisibly returns the path of the saved file.
#' @export
#' @examples
#' st <- new_sideview_state()
#' tf <- tempfile(fileext = ".json")
#' sv_save_state(st, tf)
#' unlink(tf)
sv_save_state <- function(state, file, format = NULL) {
  if (is.null(format)) {
    ext <- tolower(tools::file_ext(file))
    if (ext %in% c("json", "rds")) {
      format <- ext
    } else {
      stop("Cannot infer format from file extension '", ext, "'. Expected 'json' or 'rds'.", call. = FALSE)
    }
  } else {
    format <- tolower(format)
    if (!format %in% c("json", "rds")) {
      stop("Invalid format '", format, "'. Supported formats are 'json' and 'rds'.", call. = FALSE)
    }
  }

  dir_path <- dirname(file)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  }

  if (format == "json") {
    json_str <- jsonlite::toJSON(unclass(state), auto_unbox = TRUE, pretty = TRUE)
    writeLines(json_str, file, useBytes = TRUE)
  } else {
    saveRDS(state, file = file)
  }

  invisible(file)
}

#' Load Canvas State from File
#'
#' Deserializes a previously saved Sideview canvas workspace from a `.json` or `.rds`
#' file and returns a `sideview_state` object. Optionally launches an interactive session.
#'
#' @param file Path to the saved state file (`.json` or `.rds`).
#' @param tables Optional named list of data frames or tables to associate with loaded cards.
#'   If `NULL`, tables are discovered from the calling environment.
#' @param launch Logical; if `TRUE` and the session is interactive, launches `sideview()`
#'   with the loaded state. If non-interactive, returns the loaded state object.
#' @param format Optional format specification (`"json"` or `"rds"`). If `NULL` (default),
#'   the format is inferred from the file extension (`.json` or `.rds`).
#'
#' @return A `sideview_state` object of class `c("sideview_state", "list")`, or the gadget
#'   result if `launch = TRUE` in an interactive session.
#' @export
#' @examples
#' st <- new_sideview_state()
#' tf <- tempfile(fileext = ".json")
#' sv_save_state(st, tf)
#' loaded <- sv_load_state(tf)
#' print(loaded)
#' unlink(tf)
sv_load_state <- function(file, tables = NULL, launch = FALSE, format = NULL) {
  if (!file.exists(file)) {
    stop("State file does not exist: ", file, call. = FALSE)
  }

  if (is.null(format)) {
    ext <- tolower(tools::file_ext(file))
    if (ext %in% c("json", "rds")) {
      format <- ext
    } else {
      stop("Invalid or unsupported file format: '", ext, "'. Expected 'json' or 'rds'.", call. = FALSE)
    }
  } else {
    format <- tolower(format)
    if (!format %in% c("json", "rds")) {
      stop("Invalid format '", format, "'. Supported formats are 'json' and 'rds'.", call. = FALSE)
    }
  }

  if (format == "json") {
    state <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  } else {
    state <- readRDS(file)
  }

  if (!is.list(state)) {
    stop("Invalid state file: root object must be a list.", call. = FALSE)
  }

  class(state) <- c("sideview_state", "list")

  if (isTRUE(launch)) {
    if (interactive()) {
      if (is.null(tables)) {
        tables <- sv_find_tables(parent.frame())
      }
      if (length(tables) == 0) {
        tables <- list(
          mtcars = datasets::mtcars,
          iris = datasets::iris
        )
      }
      return(sideview(tables))
    }
  }

  state
}

#' Print Method for Sideview State Objects
#'
#' Displays a concise summary of the canvas state including version, card count,
#' and active connections.
#'
#' @param x A `sideview_state` object.
#' @param ... Unused additional arguments.
#'
#' @return Invisibly returns `x`.
#' @export
print.sideview_state <- function(x, ...) {
  version_str <- x$version %||% "0.2.0"
  n_cards <- length(x$cards)
  n_conn <- length(x$connections)

  cat(sprintf("<sideview_state v%s>\n", sub("^v", "", version_str)))
  cat(sprintf("  Cards:       %d\n", n_cards))
  cat(sprintf("  Connections: %d\n", n_conn))

  if (!is.null(x$canvas) && is.list(x$canvas)) {
    cat(sprintf("  Canvas:      zoom = %s, pan = (%s, %s)\n",
                x$canvas$zoom %||% 1,
                x$canvas$pan_x %||% 0,
                x$canvas$pan_y %||% 0))
  }

  if (!is.null(x$pipeline) && !is.null(x$pipeline$active_tab)) {
    cat(sprintf("  Active Tab:  %s\n", x$pipeline$active_tab))
  }

  invisible(x)
}
