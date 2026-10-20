# Suppress startup package build warnings
suppressWarnings(suppressPackageStartupMessages(library(shiny)))

# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

test_that("sideview_ui returns shiny.tag.list with proper dependencies and structure", {
  df1 <- data.frame(id = 1:3, name = c("Alice", "Bob", "Charlie"), stringsAsFactors = FALSE)
  df2 <- data.frame(patient_id = c(1, 2, 4), score = c(95, 80, 70), stringsAsFactors = FALSE)
  
  card1 <- sv_normalize(df1, name = "users")
  card2 <- sv_normalize(df2, name = "scores")
  
  # Also include an HTML card and a widget card
  html_card <- structure(
    list(
      id = "card_gt",
      name = "gt_summary",
      type = "html",
      data = df1,
      html_content = "<div class='gt-table-rendered'><table><tr><td>gt</td></tr></table></div>",
      dims = c(3L, 2L),
      col_types = c(id = "integer", name = "character")
    ),
    class = "sideview_card"
  )
  
  widget_card <- structure(
    list(
      id = "card_widget",
      name = "dt_table",
      type = "widget",
      data = df1,
      html_content = "<div class='htmlwidget-container'><span>widget</span></div>",
      dims = c(3L, 2L),
      col_types = c(id = "integer", name = "character")
    ),
    class = "sideview_card"
  )

  cards <- list(card1, card2, html_card, widget_card)
  ui <- sideview_ui(cards)
  
  # Must return a shiny.tag.list
  expect_s3_class(ui, "shiny.tag.list")
  
  # HTML dependencies
  deps <- htmltools::findDependencies(ui)
  dep_names <- vapply(deps, function(d) d$name, character(1))
  expect_true("sideview" %in% dep_names)
  
  sv_dep <- deps[[which(dep_names == "sideview")[1]]]
  expect_equal(sv_dep$stylesheet, "sideview.css")
  expect_true(all(c("panzoom.min.js", "sideview.js") %in% sv_dep$script))
  
  # Render UI to character to verify required DOM elements
  html_rendered <- as.character(ui)
  
  # Container, toolbar, palette, canvas, viewport, SVG overlay
  expect_match(html_rendered, "sideview-container")
  expect_match(html_rendered, "sideview-toolbar")
  expect_match(html_rendered, "sideview-palette")
  expect_match(html_rendered, "sideview-canvas")
  expect_match(html_rendered, "sideview-viewport")
  expect_match(html_rendered, "sideview-connector-svg")
  
  # Action drawer and AI bar
  expect_match(html_rendered, "sideview-drawer")
  expect_match(html_rendered, "sideview-ai-bar")
  
  # Cards and elements
  expect_match(html_rendered, "sideview-card")
  expect_match(html_rendered, "sideview-card-header")
  expect_match(html_rendered, "sideview-col-port")
  expect_match(html_rendered, "sideview-table")
  
  # Renders grid cards
  expect_match(html_rendered, "users")
  expect_match(html_rendered, "scores")
  expect_match(html_rendered, "Alice")
  expect_match(html_rendered, "patient_id")
  
  # Renders HTML and widget card content
  expect_match(html_rendered, "gt-table-rendered")
  expect_match(html_rendered, "htmlwidget-container")
})

test_that("sideview_ui works with raw data.frames or single card", {
  df <- data.frame(a = 1:2, b = c("x", "y"))
  ui_raw <- sideview_ui(df)
  expect_s3_class(ui_raw, "shiny.tag.list")
  expect_match(as.character(ui_raw), "sideview-card")
  
  ui_empty <- sideview_ui(list())
  expect_s3_class(ui_empty, "shiny.tag.list")
  expect_match(as.character(ui_empty), "sideview-container")
})

test_that("sideview_server handles column_mapped input event and dispatches code", {
  df1 <- data.frame(id = 1:3, val1 = c("A", "B", "C"), stringsAsFactors = FALSE)
  df2 <- data.frame(patient_id = 1:3, val2 = c(10, 20, 30), stringsAsFactors = FALSE)
  cards <- list(sv_normalize(df1, name = "df1"), sv_normalize(df2, name = "df2"))

  shiny::testServer(sideview_server(cards), {
    # Trigger column_mapped with different column names
    session$setInputs(column_mapped = list(
      from_table = "df1",
      from_col = "id",
      to_table = "df2",
      to_col = "patient_id",
      join_type = "left_join"
    ))
    
    # Verify code was generated and stored/dispatched
    custom_msgs <- session$userData$custom_messages
    expect_true(length(custom_msgs) >= 1)
    
    last_msg <- custom_msgs[[length(custom_msgs)]]
    expect_equal(last_msg$type, "sideview_code_update")
    expect_match(last_msg$message$code, "df1\\s*%>%\\s*dplyr::left_join\\(df2,\\s*by = c\\(\"id\" = \"patient_id\"\\)\\)")
  })
})

test_that("sideview_server handles column_renamed input event", {
  df1 <- data.frame(old_name = 1:3, stringsAsFactors = FALSE)
  cards <- list(sv_normalize(df1, name = "df1"))

  shiny::testServer(sideview_server(cards), {
    session$setInputs(column_renamed = list(
      table = "df1",
      old_col = "old_name",
      new_col = "new_name"
    ))
    
    custom_msgs <- session$userData$custom_messages
    expect_true(length(custom_msgs) >= 1)
    
    last_msg <- custom_msgs[[length(custom_msgs)]]
    expect_equal(last_msg$type, "sideview_code_update")
    expect_match(last_msg$message$code, "df1\\s*%>%\\s*dplyr::rename\\(new_name = old_name\\)")
  })
})

test_that("sideview_server handles discrepancy_check input event", {
  df1 <- data.frame(status = c("Completed", "In Prog", "Cancelled", "Unknown"), stringsAsFactors = FALSE)
  df2 <- data.frame(state = c("Completed", "InProg", "Canceled", "Missing"), stringsAsFactors = FALSE)
  cards <- list(sv_normalize(df1, name = "t1"), sv_normalize(df2, name = "t2"))

  shiny::testServer(sideview_server(cards), {
    session$setInputs(discrepancy_check = list(
      table1 = "t1",
      col1 = "status",
      table2 = "t2",
      col2 = "state"
    ))
    
    custom_msgs <- session$userData$custom_messages
    expect_true(length(custom_msgs) >= 1)
    
    disc_msgs <- Filter(function(m) m$type == "sideview_discrepancies", custom_msgs)
    expect_true(length(disc_msgs) >= 1)
    
    msg_data <- disc_msgs[[length(disc_msgs)]]$message
    expect_equal(msg_data$from_table, "t1")
    expect_equal(msg_data$to_table, "t2")
    expect_true("fuzzy_matches" %in% names(msg_data))
    expect_true("only_in_x" %in% names(msg_data))
    expect_true("only_in_y" %in% names(msg_data))
    
    # In Prog and InProg have distance 1; Cancelled and Canceled have distance 1
    f_df <- as.data.frame(msg_data$fuzzy_matches)
    expect_true(nrow(f_df) >= 1)
    expect_true(any(f_df$x == "In Prog" & f_df$y == "InProg"))
  })
})

test_that("sideview_server handles run_ai_prompt event invoking sv_call_llm", {
  df1 <- data.frame(id = 1:3, age = c(25, 30, 35))
  cards <- list(sv_normalize(df1, name = "patients"))

  fake_llm <- function(prompt, backend = "ollama", ...) {
    "patients %>% dplyr::filter(age > 28)"
  }

  shiny::testServer(sideview_server(cards, llm_fn = fake_llm), {
    session$setInputs(run_ai_prompt = list(
      prompt = "filter patients older than 28",
      tables = c("patients")
    ))
    
    custom_msgs <- session$userData$custom_messages
    expect_true(length(custom_msgs) >= 1)
    
    ai_msgs <- Filter(function(m) m$type == "sideview_code_update", custom_msgs)
    expect_true(length(ai_msgs) >= 1)
    
    last_ai_msg <- ai_msgs[[length(ai_msgs)]]
    expect_match(last_ai_msg$message$code, "patients\\s*%>%\\s*dplyr::filter\\(age > 28\\)")
  })
})

test_that("sideview_server handles inject_script and send_console events", {
  cards <- list(sv_normalize(data.frame(x = 1), name = "df"))

  injected_code <- NULL
  fake_insert <- function(code, ...) {
    injected_code <<- code
    list(success = TRUE, destination = "editor", code = code, message = "OK")
  }

  console_code <- NULL
  fake_console <- function(code, ...) {
    console_code <<- code
    list(success = TRUE, destination = "console", code = code, message = "OK")
  }

  shiny::testServer(sideview_server(cards, insert_fn = fake_insert, console_fn = fake_console), {
    # Test inject_script
    session$setInputs(inject_script = list(code = "df %>% dplyr::mutate(y = x * 2)"))
    expect_equal(injected_code, "df %>% dplyr::mutate(y = x * 2)")
    
    # Test send_console
    session$setInputs(send_console = list(code = "summary(df)"))
    expect_equal(console_code, "summary(df)")
  })
})

test_that("sideview normalizes multiple table objects and sideview_addin finds data.frames", {
  df1 <- data.frame(a = 1:2)
  df2 <- data.frame(b = 3:4)
  mat <- matrix(1:4, nrow = 2)

  # sideview(...) in non-interactive/run=FALSE mode
  app <- sideview(table1 = df1, table2 = df2, table3 = mat, run = FALSE)
  expect_s3_class(app, "shiny.appobj")
  
  cards <- attr(app, "cards") %||% app$cards
  expect_true(is.list(cards))
  expect_equal(length(cards), 3)
  expect_equal(cards[[1]]$name, "table1")
  expect_equal(cards[[2]]$name, "table2")
  expect_equal(cards[[3]]$name, "table3")
  
  # Test sideview_addin environment scanning
  test_env <- new.env(parent = emptyenv())
  test_env$df_a <- data.frame(x = 1:5)
  test_env$df_b <- dplyr::tibble(y = c("a", "b"))
  test_env$not_a_df <- "hello world"
  test_env$num_vec <- 1:100
  
  found_tables <- sv_find_tables(test_env)
  expect_equal(length(found_tables), 2)
  expect_true(all(c("df_a", "df_b") %in% names(found_tables)))
  expect_false("not_a_df" %in% names(found_tables))
  expect_false("num_vec" %in% names(found_tables))
  
  # sideview_addin with run=FALSE returns appobj
  addin_app <- sideview_addin(env = test_env, run = FALSE)
  expect_s3_class(addin_app, "shiny.appobj")
  addin_cards <- attr(addin_app, "cards") %||% addin_app$cards
  expect_equal(length(addin_cards), 2)

  # Test collision-free handling of datasets named 'title', 'viewer', 'run'
  collision_env <- new.env(parent = emptyenv())
  collision_env$title <- data.frame(id = 1:2)
  collision_env$run <- data.frame(val = 3:4)
  collision_app <- sideview_addin(env = collision_env, run = FALSE)
  c_cards <- attr(collision_app, "cards") %||% collision_app$cards
  expect_equal(length(c_cards), 2)
  expect_true(all(c("title", "run") %in% vapply(c_cards, function(c) c$name, character(1))))
})

test_that("sideview_ui renders custom title and real htmlwidget objects", {
  custom_ui <- sideview_ui(list(), title = "Clinical Trial 101")
  ui_str <- as.character(custom_ui)
  expect_true(grepl("Clinical Trial 101", ui_str))

  # Real htmlwidget card
  skip_if_not_installed("htmlwidgets")
  widget <- htmlwidgets::createWidget("testWidget", list(x = 1), width = 200, height = 200)
  card_w <- sv_normalize(widget, name = "my_w")
  w_ui <- sideview_ui(card_w)
  expect_true(grepl("testWidget", as.character(w_ui)))
})

test_that("sideview_server gracefully ignores incomplete discrepancy_check events", {
  cards <- list(sv_normalize(data.frame(x = 1), name = "df"))
  shiny::testServer(sideview_server(cards), {
    # Incomplete inputs should not crash or throw errors
    session$setInputs(discrepancy_check = list(table1 = "df"))
    session$setInputs(discrepancy_check = list())
    session$setInputs(discrepancy_check = NULL)
    expect_true(TRUE)
  })
})

test_that("inst/rstudio/addins.dcf exists and is a valid DCF file", {
  find_dcf <- function() {
    candidates <- c(
      file.path("inst", "rstudio", "addins.dcf"),
      file.path("..", "inst", "rstudio", "addins.dcf"),
      file.path("..", "..", "inst", "rstudio", "addins.dcf"),
      system.file("rstudio", "addins.dcf", package = "sideview")
    )
    for (c in candidates) {
      if (nzchar(c) && file.exists(c)) return(normalizePath(c))
    }
    file.path("inst", "rstudio", "addins.dcf")
  }

  dcf_path <- find_dcf()
  expect_true(file.exists(dcf_path), info = paste("addins.dcf missing at:", dcf_path))
  
  dcf <- read.dcf(dcf_path)
  expect_true(nrow(dcf) >= 1)
  expect_true("Name" %in% colnames(dcf))
  expect_true("Binding" %in% colnames(dcf))
  expect_true("Description" %in% colnames(dcf))
  
  # Check binding value
  expect_true("sideview_addin" %in% dcf[, "Binding"])
  expect_true(all(nchar(dcf[, "Name"]) > 0))
  expect_true(all(nchar(dcf[, "Description"]) > 0))
})
