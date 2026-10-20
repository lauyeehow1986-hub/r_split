#' Locate Sideview Web Assets Directory
#'
#' @return Absolute path to the web assets directory.
#' @noRd
find_sideview_www <- function() {
  candidates <- c(
    system.file("www", package = "sideview"),
    file.path("inst", "www"),
    file.path("..", "inst", "www"),
    file.path("..", "..", "inst", "www"),
    file.path(".", "www")
  )
  for (cand in candidates) {
    if (nzchar(cand) && dir.exists(cand)) {
      return(normalizePath(cand))
    }
  }
  system.file("www", package = "sideview")
}

#' HTML Dependency for Sideview Assets
#'
#' @return An `htmltools::htmlDependency` object.
#' @noRd
sideview_html_dependency <- function() {
  www_dir <- find_sideview_www()
  htmltools::htmlDependency(
    name = "sideview",
    version = "0.1.0",
    src = c(file = www_dir),
    stylesheet = "sideview.css",
    script = c("panzoom.min.js", "sideview.js")
  )
}

#' Render a Single Card to Shiny HTML Tags
#'
#' @param card A `sideview_card` object.
#' @param index Integer index of the card on the canvas.
#' @return A `shiny.tag` element.
#' @noRd
render_card_tag <- function(card, index = 1L) {
  card_id <- card$id %||% paste0("card_", index)
  card_name <- card$name %||% paste0("Table_", index)
  card_type <- card$type %||% "grid"
  
  initial_x <- if (!is.null(card$x)) card$x else 40 + (index - 1) * 360
  initial_y <- if (!is.null(card$y)) card$y else 60 + ((index - 1) %% 2) * 50
  
  dims_text <- if (!is.null(card$dims) && length(card$dims) >= 2) {
    paste0(card$dims[1], " \u00d7 ", card$dims[2])
  } else {
    ""
  }
  
  # Header
  header_tag <- htmltools::tags$div(
    class = "sideview-card-header",
    htmltools::tags$div(
      class = "sideview-card-title-group",
      htmltools::tags$span(class = "sideview-card-title", card_name),
      htmltools::tags$span(class = "sideview-badge sideview-badge-type", card_type),
      if (nzchar(dims_text)) htmltools::tags$span(class = "sideview-badge", dims_text)
    ),
    htmltools::tags$div(
      class = "sideview-card-actions",
      htmltools::tags$button(
        class = "sideview-icon-btn",
        `data-action` = "sync-scroll",
        title = "Synchronize vertical scrolling",
        htmltools::HTML("&#128279;")
      ),
      htmltools::tags$button(
        class = "sideview-icon-btn",
        `data-action` = "minimize-card",
        title = "Minimize",
        htmltools::HTML("&minus;")
      )
    )
  )
  
  # Body
  body_content <- NULL
  if (card_type == "grid" && !is.null(card$data) && is.data.frame(card$data)) {
    df <- card$data
    col_names <- colnames(df)
    col_types <- card$col_types %||% character(0)
    
    # Table header
    th_tags <- lapply(col_names, function(col) {
      c_type <- col_types[col] %||% ""
      htmltools::tags$th(
        `data-col-name` = col,
        htmltools::tags$div(
          class = "col-header-wrap",
          htmltools::tags$div(
            htmltools::tags$span(class = "sideview-col-name", col),
            if (!is.null(c_type) && !is.na(c_type) && nzchar(c_type)) {
              htmltools::tags$span(class = "sideview-col-type", paste0("(", c_type, ")"))
            }
          ),
          htmltools::tags$span(
            class = "sideview-col-port",
            `data-col-name` = col,
            title = "Connect to map field"
          )
        )
      )
    })
    
    # Table rows (virtualized preview up to 500 rows)
    max_preview <- min(nrow(df), 500L)
    row_tags <- vector("list", max_preview)
    for (r in seq_len(max_preview)) {
      td_tags <- lapply(col_names, function(col) {
        val <- df[[col]][r]
        val_str <- if (is.null(val) || is.na(val)) "NA" else as.character(val)
        is_num <- is.numeric(df[[col]])
        htmltools::tags$td(
          class = if (is_num) "is-number" else NULL,
          val_str
        )
      })
      row_tags[[r]] <- htmltools::tags$tr(td_tags)
    }
    
    body_content <- htmltools::tags$table(
      class = "sideview-table",
      htmltools::tags$thead(htmltools::tags$tr(th_tags)),
      htmltools::tags$tbody(row_tags)
    )
  } else if (!is.null(card$widget)) {
    body_content <- htmltools::as.tags(card$widget)
  } else if (!is.null(card$html_content) && nzchar(card$html_content)) {
    body_content <- htmltools::HTML(card$html_content)
  } else {
    body_content <- htmltools::tags$div(
      class = "sideview-placeholder",
      paste("No preview available for", card_name)
    )
  }
  
  body_tag <- htmltools::tags$div(class = "sideview-card-body", body_content)
  
  htmltools::tags$div(
    class = "sideview-card panzoom-exclude",
    id = card_id,
    `data-card-id` = card_id,
    `data-card-name` = card_name,
    style = sprintf("left: %dpx; top: %dpx;", as.integer(initial_x), as.integer(initial_y)),
    header_tag,
    body_tag
  )
}

#' Sideview User Interface
#'
#' Builds the complete 2D infinite canvas user interface for Sideview,
#' containing the draggable table cards, panzoom canvas, SVG connector overlay,
#' action drawer, and natural language AI bar with all HTML dependencies attached.
#'
#' @param cards A `sideview_card` object, a list of `sideview_card` objects,
#'   or tabular objects to be normalized.
#' @param title Display title for the application toolbar. Default is "Sideview Canvas".
#'
#' @return A `shiny.tag.list` UI definition.
#' @export
sideview_ui <- function(cards = list(), title = "Sideview Canvas") {
  # Normalize input into a list of sideview_cards
  if (is.null(cards)) {
    card_list <- list()
  } else if (inherits(cards, "sideview_card") || is.data.frame(cards) ||
             inherits(cards, c("gt_tbl", "flextable", "table"))) {
    card_list <- list(cards)
  } else if (is.list(cards)) {
    card_list <- cards
  } else {
    card_list <- list(cards)
  }
  
  normalized_cards <- list()
  for (i in seq_along(card_list)) {
    c_item <- card_list[[i]]
    if (inherits(c_item, "sideview_card")) {
      normalized_cards[[length(normalized_cards) + 1]] <- c_item
    } else {
      nm <- names(card_list)[i]
      if (is.null(nm) || !nzchar(nm)) {
        nm <- paste0("Table_", i)
      }
      norm <- tryCatch(sv_normalize(c_item, name = nm), error = function(e) NULL)
      if (!is.null(norm)) {
        normalized_cards[[length(normalized_cards) + 1]] <- norm
      }
    }
  }
  
  # Render all card tags
  rendered_cards <- lapply(seq_along(normalized_cards), function(idx) {
    render_card_tag(normalized_cards[[idx]], index = idx)
  })
  
  # Toolbar
  toolbar_tag <- htmltools::tags$div(
    class = "sideview-toolbar",
    htmltools::tags$span(class = "sideview-brand", title),
    htmltools::tags$span(class = "sideview-toolbar-divider"),
    htmltools::tags$button(class = "sideview-btn", `data-action` = "zoom-in", title = "Zoom In", "+"),
    htmltools::tags$button(class = "sideview-btn", `data-action` = "zoom-out", title = "Zoom Out", "-"),
    htmltools::tags$button(class = "sideview-btn", `data-action` = "zoom-reset", title = "Reset View", "100%"),
    htmltools::tags$span(class = "sideview-toolbar-divider"),
    htmltools::tags$button(class = "sideview-btn active", `data-action` = "toggle-snap", title = "Snap to Edge", "Snap"),
    htmltools::tags$button(class = "sideview-btn", `data-action` = "toggle-drawer", title = "Toggle Drawer", "Drawer")
  )
  
  # Swatch palette
  palette_tag <- htmltools::tags$div(
    class = "sideview-palette",
    htmltools::tags$span(class = "sideview-palette-label", "Highlight:"),
    htmltools::tags$div(class = "sideview-swatch sideview-swatch-blue", `data-color` = "blue", title = "Blue"),
    htmltools::tags$div(class = "sideview-swatch sideview-swatch-green", `data-color` = "green", title = "Green"),
    htmltools::tags$div(class = "sideview-swatch sideview-swatch-amber", `data-color` = "amber", title = "Amber"),
    htmltools::tags$div(class = "sideview-swatch sideview-swatch-rose", `data-color` = "rose", title = "Rose"),
    htmltools::tags$div(class = "sideview-swatch sideview-swatch-purple", `data-color` = "purple", title = "Purple"),
    htmltools::tags$div(class = "sideview-swatch sideview-swatch-clear", `data-color` = "clear", title = "Clear Highlight")
  )
  
  # Canvas & Viewport with SVG overlay
  canvas_tag <- htmltools::tags$div(
    class = "sideview-canvas",
    htmltools::tags$div(
      class = "sideview-viewport",
      htmltools::tags$svg(
        class = "sideview-connector-svg",
        width = "100%",
        height = "100%"
      ),
      rendered_cards
    )
  )
  
  # Action drawer
  drawer_tag <- htmltools::tags$div(
    class = "sideview-drawer collapsed",
    htmltools::tags$div(
      class = "sideview-drawer-header",
      htmltools::tags$span(class = "sideview-drawer-title", "Tidyverse Operations"),
      htmltools::tags$button(class = "sideview-icon-btn", `data-action` = "close-drawer", htmltools::HTML("&times;"))
    ),
    htmltools::tags$div(
      class = "sideview-drawer-tabs",
      htmltools::tags$button(class = "sideview-drawer-tab active", `data-tab` = "join", "Join"),
      htmltools::tags$button(class = "sideview-drawer-tab", `data-tab` = "mutate", "Mutate"),
      htmltools::tags$button(class = "sideview-drawer-tab", `data-tab` = "recode", "Recode"),
      htmltools::tags$button(class = "sideview-drawer-tab", `data-tab` = "discrepancy", "Discrepancy")
    ),
    htmltools::tags$div(
      class = "sideview-drawer-content",
      htmltools::tags$p(class = "sideview-drawer-desc", "Connect columns to generate join or mutation pipelines."),
      htmltools::tags$pre(class = "sideview-code-block", htmltools::tags$code(class = "sideview-code-text", "# Connect two columns to generate pipeline code"))
    ),
    htmltools::tags$div(
      class = "sideview-drawer-actions",
      htmltools::tags$button(class = "sideview-btn sideview-btn-primary", `data-action` = "inject-script", title = "Insert code into active RStudio script", "Insert Script"),
      htmltools::tags$button(class = "sideview-btn", `data-action` = "send-console", title = "Send code directly to RStudio console", "Run Console"),
      htmltools::tags$button(class = "sideview-btn", `data-action` = "copy-code", "Copy")
    )
  )
  
  # Floating AI bar
  ai_bar_tag <- htmltools::tags$div(
    class = "sideview-ai-bar",
    htmltools::tags$span(class = "sideview-ai-icon", htmltools::HTML("&#10024;")),
    htmltools::tags$input(type = "text", class = "sideview-ai-input", placeholder = "Ask AI: e.g., join patients and labs on ID, impute missing values..."),
    htmltools::tags$button(class = "sideview-ai-send", `data-action` = "send-ai", "Send")
  )
  
  # Client bootstrap script
  init_script <- htmltools::tags$script(htmltools::HTML("
    (function() {
      function start() {
        if (typeof initSideview === 'function') {
          initSideview('.sideview-container');
        }
      }
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
      } else {
        start();
      }
    })();
  "))
  
  # Complete container
  container_tag <- htmltools::tags$div(
    class = "sideview-container",
    toolbar_tag,
    palette_tag,
    canvas_tag,
    drawer_tag,
    ai_bar_tag,
    init_script
  )
  
  htmltools::tagList(
    sideview_html_dependency(),
    container_tag
  )
}
