# Null-default helper
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Internal Implementation of Sideview Server
#'
#' @param input Shiny input object.
#' @param output Shiny output object.
#' @param session Shiny session object.
#' @param cards Raw cards or normalized `sideview_card` list.
#' @param llm_fn Function to call for AI completions.
#' @param insert_fn Function to call for editor code insertion.
#' @param console_fn Function to call for console execution.
#' @noRd
sideview_server_impl <- function(input, output, session, cards, llm_fn, insert_fn, console_fn) {
  # Normalize input cards
  card_list <- if (inherits(cards, "sideview_card") || is.data.frame(cards) ||
                   inherits(cards, c("gt_tbl", "flextable", "table"))) {
    list(cards)
  } else if (is.list(cards)) {
    cards
  } else {
    list(cards)
  }

  normalized_cards <- list()
  cards_by_name <- list()
  cards_by_id <- list()

  for (i in seq_along(card_list)) {
    c_item <- card_list[[i]]
    if (!inherits(c_item, "sideview_card")) {
      nm <- names(card_list)[i]
      if (is.null(nm) || !nzchar(nm)) nm <- paste0("Table_", i)
      c_item <- tryCatch(sv_normalize(c_item, name = nm), error = function(e) NULL)
    }
    if (!is.null(c_item)) {
      normalized_cards[[length(normalized_cards) + 1]] <- c_item
      if (!is.null(c_item$name) && nzchar(c_item$name)) {
        cards_by_name[[c_item$name]] <- c_item
      }
      if (!is.null(c_item$id) && nzchar(c_item$id)) {
        cards_by_id[[c_item$id]] <- c_item
      }
    }
  }

  # Helper to dispatch custom messages and record them for testing/audit
  dispatch_message <- function(type, message) {
    if (is.null(session$userData$custom_messages)) {
      session$userData$custom_messages <- list()
    }
    session$userData$custom_messages[[length(session$userData$custom_messages) + 1]] <- list(
      type = type,
      message = message
    )
    tryCatch(session$sendCustomMessage(type, message), error = function(e) NULL)
  }

  # 1. Column Mapped -> Join Code Generation
  shiny::observeEvent(input$column_mapped, {
    evt <- input$column_mapped
    if (is.null(evt)) return()

    from_tbl <- evt$from_table %||% evt$table1
    from_col <- evt$from_col %||% evt$col1
    to_tbl <- evt$to_table %||% evt$table2
    to_col <- evt$to_col %||% evt$col2
    join_type <- evt$join_type %||% "left_join"

    code <- tryCatch({
      sv_code_join(
        df1 = from_tbl,
        df2 = to_tbl,
        col1 = from_col,
        col2 = to_col,
        join_type = join_type,
        pipe = TRUE
      )
    }, error = function(e) {
      sprintf("# Error generating join code: %s", conditionMessage(e))
    })

    dispatch_message("sideview_code_update", list(code = code))
  }, ignoreInit = FALSE)

  # 2. Column Renamed -> Rename Code Generation
  shiny::observeEvent(input$column_renamed, {
    evt <- input$column_renamed
    if (is.null(evt)) return()

    tbl <- evt$table %||% evt$table_name %||% "df"
    old_c <- evt$old_col
    new_c <- evt$new_col

    code <- tryCatch({
      sv_code_rename(
        df_name = tbl,
        old_col = old_c,
        new_col = new_c,
        pipe = TRUE
      )
    }, error = function(e) {
      sprintf("# Error generating rename code: %s", conditionMessage(e))
    })

    dispatch_message("sideview_code_update", list(code = code))
  }, ignoreInit = FALSE)

  # 3. Discrepancy Check -> Discrepancy Analysis
  shiny::observeEvent(input$discrepancy_check, {
    evt <- input$discrepancy_check
    if (is.null(evt)) return()

    tbl1 <- evt$table1 %||% evt$from_table
    col1 <- evt$col1 %||% evt$from_col
    tbl2 <- evt$table2 %||% evt$to_table
    col2 <- evt$col2 %||% evt$to_col

    if (is.null(tbl1) || is.null(tbl2) || is.null(col1) || is.null(col2) ||
        !nzchar(tbl1) || !nzchar(tbl2) || !nzchar(col1) || !nzchar(col2)) return()

    tryCatch({
      # Resolve card data
      c1 <- cards_by_name[[tbl1]] %||% cards_by_id[[tbl1]]
      c2 <- cards_by_name[[tbl2]] %||% cards_by_id[[tbl2]]

      x_vec <- if (!is.null(c1) && !is.null(c1$data) && col1 %in% colnames(c1$data)) {
        c1$data[[col1]]
      } else {
        NULL
      }
      y_vec <- if (!is.null(c2) && !is.null(c2$data) && col2 %in% colnames(c2$data)) {
        c2$data[[col2]]
      } else {
        NULL
      }

      disc <- sv_detect_discrepancies(x_vec, y_vec)

      dispatch_message("sideview_discrepancies", list(
        from_table = tbl1,
        to_table = tbl2,
        exact_matches = disc$exact_matches,
        fuzzy_matches = disc$fuzzy_matches,
        only_in_x = disc$only_in_x,
        only_in_y = disc$only_in_y,
        stats = disc$stats
      ))
    }, error = function(e) {
      message("sideview discrepancy analysis warning: ", conditionMessage(e))
    })
  }, ignoreInit = FALSE)

  # 4. Run AI Prompt -> LLM Generation
  shiny::observeEvent(input$run_ai_prompt, {
    evt <- input$run_ai_prompt
    if (is.null(evt) || is.null(evt$prompt) || !nzchar(evt$prompt)) return()

    schema <- sv_build_schema_context(normalized_cards)
    prompt_obj <- sv_build_prompt(evt$prompt, schema_context = schema)
    backend <- evt$backend %||% getOption("sideview.llm_backend", Sys.getenv("SIDEVIEW_LLM_BACKEND", "ollama"))
    model <- evt$model %||% getOption("sideview.llm_model", NULL)
    endpoint <- evt$endpoint %||% getOption("sideview.llm_endpoint", NULL)
    api_key <- evt$api_key %||% getOption("sideview.llm_api_key", NULL)

    ai_code <- tryCatch({
      raw_resp <- llm_fn(
        prompt = prompt_obj,
        backend = backend,
        model = model,
        endpoint = endpoint,
        api_key = api_key
      )
      extracted <- sv_extract_code(raw_resp)
      if (nzchar(extracted)) extracted else raw_resp
    }, error = function(e) {
      paste0("# AI generation failed: ", conditionMessage(e))
    })

    dispatch_message("sideview_code_update", list(code = ai_code))
  }, ignoreInit = FALSE)

  # 5. Inject Script -> rstudioapi insertion
  shiny::observeEvent(input$inject_script, {
    evt <- input$inject_script
    if (is.null(evt)) return()
    code <- if (is.list(evt)) evt$code else evt
    res <- insert_fn(code)
    dispatch_message("sideview_inject_result", res)
  }, ignoreInit = FALSE)

  # 6. Send Console -> rstudioapi console execution (queued)
  shiny::observeEvent(input$send_console, {
    evt <- input$send_console
    if (is.null(evt)) return()
    code <- if (is.list(evt)) evt$code else evt
    res <- console_fn(code)
    if (isTRUE(res$success)) {
      res$message <- "Code queued to RStudio console (will execute as soon as the gadget closes, or use 'Run & Exit')!"
    }
    dispatch_message("sideview_console_result", res)
  }, ignoreInit = FALSE)

  # 6b. Send Console & Exit -> stops gadget so RStudio console executes immediately
  shiny::observeEvent(input$send_console_and_exit, {
    evt <- input$send_console_and_exit
    if (is.null(evt)) return()
    code <- if (is.list(evt)) evt$code else evt
    res <- console_fn(code)
    dispatch_message("sideview_console_result", res)
    tryCatch(shiny::stopApp(), error = function(e) NULL)
  }, ignoreInit = FALSE)

  # 6c. Evaluate in .GlobalEnv -> executes code in active R session environment
  shiny::observeEvent(input$eval_env, {
    evt <- input$eval_env
    if (is.null(evt)) return()
    code <- if (is.list(evt)) evt$code else evt
    eval_res <- tryCatch({
      expr <- parse(text = code)
      out <- eval(expr, envir = .GlobalEnv)
      msg <- if (is.data.frame(out)) {
        sprintf("Executed in R environment: %d rows x %d cols.", nrow(out), ncol(out))
      } else {
        "Executed successfully in R environment."
      }
      list(success = TRUE, destination = "environment", message = msg)
    }, error = function(e) {
      list(success = FALSE, destination = "environment", message = paste0("Execution error: ", conditionMessage(e)))
    })
    dispatch_message("sideview_eval_result", eval_res)
  }, ignoreInit = FALSE)

  # 7. Highlight Changes
  shiny::observeEvent(input$sideview_highlight_changed, {
    # Highlight events can be captured or relayed if needed
  }, ignoreInit = FALSE)
}

#' Sideview Server Logic
#'
#' Orchestrates bi-directional Shiny reactivity between the infinite 2D canvas
#' and the R session. Handles field mapping (`column_mapped`), column renaming
#' (`column_renamed`), discrepancy calculations (`discrepancy_check`), natural
#' language AI prompts (`run_ai_prompt`), RStudio script injection (`inject_script`),
#' and RStudio console execution (`send_console`).
#'
#' @param cards A `sideview_card` object, a list of `sideview_card` objects,
#'   or tabular objects to be normalized.
#' @param ... Additional arguments.
#' @param llm_fn Function used to execute LLM queries (default `sv_call_llm`).
#' @param insert_fn Function used to insert code into active RStudio document (default `sv_insert_code`).
#' @param console_fn Function used to send code to RStudio console (default `sv_send_to_console`).
#'
#' @return A Shiny server function `function(input, output, session)`.
#' @export
sideview_server <- function(cards = list(),
                            ...,
                            llm_fn = sv_call_llm,
                            insert_fn = sv_insert_code,
                            console_fn = sv_send_to_console) {
  dots <- list(...)
  # If invoked directly as sideview_server(input, output, session, ...)
  if (length(dots) >= 2 && inherits(dots[[2]], c("ShinySession", "MockShinySession"))) {
    input <- cards
    output <- dots[[1]]
    session <- dots[[2]]
    extra_cards <- if (length(dots) >= 3) dots[[3]] else list()
    return(sideview_server_impl(input, output, session, extra_cards, llm_fn, insert_fn, console_fn))
  }

  function(input, output, session) {
    sideview_server_impl(input, output, session, cards, llm_fn, insert_fn, console_fn)
  }
}
