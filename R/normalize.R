#' Universal Normalization Engine for Sideview Cards
#'
#' Converts various R table formats (data.frame, tibble, table, gt, flextable, htmlwidgets)
#' into a standardized `sideview_card` S3 object for rendering on the 2D infinite canvas.
#'
#' @param x An object to normalize (data.frame, tibble, table, gt, flextable, htmlwidget).
#' @param name Optional display name for the card.
#' @param id Optional unique identifier for the card.
#' @param ... Additional arguments passed to methods.
#'
#' @return An object of class `sideview_card`.
#' @export
sv_normalize <- function(x, name = NULL, id = NULL, ...) {
  UseMethod("sv_normalize")
}

# Internal monotonic counter for predictable, side-effect-free ID generation
.card_counter_env <- new.env(parent = emptyenv())
.card_counter_env$val <- 0L

#' Generate a unique ID for a card without perturbing .Random.seed
#' @noRd
generate_card_id <- function(prefix = "card") {
  .card_counter_env$val <- .card_counter_env$val + 1L
  sprintf("%s_%06d", prefix, .card_counter_env$val)
}

#' Create a sideview_card S3 object
#' @noRd
new_sideview_card <- function(id = NULL,
                              name = NULL,
                              type = c("grid", "html", "widget"),
                              data = NULL,
                              html_content = NULL,
                              dims = NULL,
                              col_types = NULL,
                              widget = NULL) {
  type <- match.arg(type)

  if (is.null(id) || length(id) == 0L || is.na(id[1]) || !nzchar(as.character(id[1]))) {
    id <- generate_card_id()
  } else {
    id <- as.character(id[1])
  }

  if (is.null(name) || length(name) == 0L || is.na(name[1]) || !nzchar(as.character(name[1]))) {
    name <- "Table"
  } else {
    name <- as.character(name[1])
  }

  if (!is.null(data) && is.data.frame(data)) {
    if (is.null(dims)) {
      dims <- c(nrow(data), ncol(data))
    }
    if (is.null(col_types)) {
      col_types <- vapply(data, function(col) class(col)[1], character(1))
    }
  }

  structure(
    list(
      id = id,
      name = name,
      type = type,
      data = data,
      html_content = html_content,
      dims = dims,
      col_types = col_types,
      widget = widget
    ),
    class = c("sideview_card", "list")
  )
}

#' @export
sv_normalize.data.frame <- function(x, name = NULL, id = NULL, ...) {
  if (is.null(name)) name <- "Data"
  new_sideview_card(
    id = id,
    name = name,
    type = "grid",
    data = x
  )
}

#' @export
sv_normalize.table <- function(x, name = NULL, id = NULL, ...) {
  if (is.null(name)) name <- "Table"
  df <- as.data.frame(x, stringsAsFactors = FALSE)
  new_sideview_card(
    id = id,
    name = name,
    type = "grid",
    data = df
  )
}

#' @export
sv_normalize.gt_tbl <- function(x, name = NULL, id = NULL, ...) {
  if (is.null(name)) name <- "gt_Table"
  html <- if (requireNamespace("gt", quietly = TRUE)) {
    as.character(gt::as_raw_html(x))
  } else {
    stop("Package 'gt' must be installed to normalize gt_tbl objects.", call. = FALSE)
  }

  raw_data <- tryCatch(
    as.data.frame(x[["_data"]]),
    error = function(e) NULL
  )

  new_sideview_card(
    id = id,
    name = name,
    type = "html",
    data = raw_data,
    html_content = html
  )
}

#' @export
sv_normalize.flextable <- function(x, name = NULL, id = NULL, ...) {
  if (is.null(name)) name <- "flextable"
  html <- if (requireNamespace("flextable", quietly = TRUE)) {
    as.character(flextable::htmltools_value(x))
  } else {
    stop("Package 'flextable' must be installed to normalize flextable objects.", call. = FALSE)
  }

  raw_data <- tryCatch(
    as.data.frame(x[["body"]][["dataset"]]),
    error = function(e) NULL
  )

  new_sideview_card(
    id = id,
    name = name,
    type = "html",
    data = raw_data,
    html_content = html
  )
}

#' @export
sv_normalize.htmlwidget <- function(x, name = NULL, id = NULL, ...) {
  if (is.null(name)) name <- "Widget"
  new_sideview_card(
    id = id,
    name = name,
    type = "widget",
    data = NULL,
    widget = x
  )
}

#' @export
sv_normalize.default <- function(x, name = NULL, id = NULL, ...) {
  if (is.function(x) || is.environment(x)) {
    stop(sprintf("Cannot normalize object of class '%s' to sideview card.", paste(class(x), collapse = ", ")), call. = FALSE)
  }

  df <- tryCatch(
    as.data.frame(x, stringsAsFactors = FALSE),
    error = function(e) NULL
  )

  if (!is.null(df) && is.data.frame(df)) {
    if (is.null(name)) name <- "Data"
    return(new_sideview_card(
      id = id,
      name = name,
      type = "grid",
      data = df
    ))
  }

  stop(sprintf("Cannot normalize object of class '%s' to sideview card.", paste(class(x), collapse = ", ")), call. = FALSE)
}

#' @export
print.sideview_card <- function(x, ...) {
  cat(sprintf("<sideview_card [%s]>\n", x$type))
  cat(sprintf("  ID:   %s\n", x$id))
  cat(sprintf("  Name: %s\n", x$name))
  if (!is.null(x$dims)) {
    cat(sprintf("  Dims: %d rows x %d cols\n", x$dims[1], x$dims[2]))
  }
  invisible(x)
}
