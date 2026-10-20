# Comprehensive End-to-End Integration Test Suite for sideview
# Verifies full pipeline across all modules:
# 1. Ingestion & normalization of heterogeneous tables (data.frame, tibble, table, gt, flextable, widget)
# 2. Codegen (joins, renames, mutates, filters, selects) with zero parse errors
# 3. Categorical discrepancy detection & recoding
# 4. LLM schema synthesis, prompt construction, and response parsing
# 5. RStudio code delivery and console fallback
# 6. HTML widget creation, Shiny integration, and standalone HTML export
# 7. Complete multi-step data transformation workflow evaluation

suppressWarnings(suppressPackageStartupMessages({
  library(testthat)
  library(shiny)
  library(htmlwidgets)
  library(htmltools)
  library(dplyr)
  library(httr2)
  library(jsonlite)
}))

# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

test_that("e2e: heterogeneous table ingestion and normalization across multiple table formats", {
  skip_if_not_installed("gt")
  skip_if_not_installed("flextable")

  # 1. Standard data.frame
  patients_df <- data.frame(
    patient_id = c("P01", "P02", "P03", "P04"),
    age = c(45, 52, 38, 61),
    weight_kg = c(70, 85, 62, 90),
    height_cm = c(175, 180, 165, 172),
    gender_raw = c("Male", "Female", "M", "Fem"),
    stringsAsFactors = FALSE
  )

  # 2. Tibble
  visits_tbl <- dplyr::tibble(
    subject_id = c("P01", "P02", "P03", "P05"),
    visit_date = as.Date(c("2024-01-10", "2024-01-15", "2024-02-01", "2024-02-10")),
    systolic_bp = c(120, 140, 115, 130),
    sex_std = c("Male", "Female", "Female", "Male")
  )

  # 3. Base R table
  dx_table <- table(c("Hypertension", "Diabetes", "Hypertension", "Asthma", "Diabetes"))

  # 4. gt table
  gt_summary <- gt::gt(patients_df[, c("patient_id", "age", "gender_raw")])

  # 5. flextable
  flex_summary <- flextable::flextable(as.data.frame(visits_tbl[, c("subject_id", "systolic_bp")]))

  # 6. htmlwidget
  dummy_widget <- htmlwidgets::createWidget("testWidget", x = list(val = 42), width = 300, height = 200)

  # Normalize all datasets
  c_df <- sv_normalize(patients_df, name = "patients")
  c_tbl <- sv_normalize(visits_tbl, name = "visits")
  c_tab <- sv_normalize(dx_table, name = "diagnoses")
  c_gt <- sv_normalize(gt_summary, name = "gt_patients")
  c_ft <- sv_normalize(flex_summary, name = "flex_visits")
  c_wid <- sv_normalize(dummy_widget, name = "wid_summary")

  # Check class assignments
  expect_s3_class(c_df, "sideview_card")
  expect_s3_class(c_tbl, "sideview_card")
  expect_s3_class(c_tab, "sideview_card")
  expect_s3_class(c_gt, "sideview_card")
  expect_s3_class(c_ft, "sideview_card")
  expect_s3_class(c_wid, "sideview_card")

  # Verify types and dimensions
  expect_equal(c_df$type, "grid")
  expect_equal(c_df$dims, c(4L, 5L))
  expect_equal(nrow(c_df$data), 4L)
  expect_equal(ncol(c_df$data), 5L)

  expect_equal(c_tbl$type, "grid")
  expect_equal(c_tbl$dims, c(4L, 4L))

  expect_equal(c_tab$type, "grid")
  expect_equal(ncol(c_tab$data), 2L) # Var1, Freq
  expect_equal(c_tab$dims, c(3L, 2L))

  expect_equal(c_gt$type, "html")
  expect_true(grepl("<table", c_gt$html_content))
  expect_equal(c_gt$dims, c(4L, 3L))
  expect_equal(nrow(c_gt$data), 4L)

  expect_equal(c_ft$type, "html")
  expect_true(is.character(c_ft$html_content) && nchar(c_ft$html_content) > 0)
  expect_equal(c_ft$dims, c(4L, 2L))
  expect_equal(nrow(c_ft$data), 4L)

  expect_equal(c_wid$type, "widget")
  expect_s3_class(c_wid$widget, "htmlwidget")
})

test_that("e2e: relational joins and data transformation pipeline generates zero-syntax-error R code", {
  # Verify all code generator functions parse cleanly with zero syntax errors

  # 1. Joins: left, inner, full, anti
  join_left <- sv_code_join("patients", "visits", "patient_id", "subject_id", join_type = "left")
  expect_equal(join_left, 'dplyr::left_join(patients, visits, by = c("patient_id" = "subject_id"))')
  expect_silent(parse(text = join_left))

  join_inner <- sv_code_join("patients", "visits", "patient_id", "subject_id", join_type = "inner")
  expect_equal(join_inner, 'dplyr::inner_join(patients, visits, by = c("patient_id" = "subject_id"))')
  expect_silent(parse(text = join_inner))

  join_full <- sv_code_join("patients", "visits", "id", "id", join_type = "full")
  expect_equal(join_full, 'dplyr::full_join(patients, visits, by = "id")')
  expect_silent(parse(text = join_full))

  join_anti <- sv_code_join("patients", "visits", "patient_id", "subject_id", join_type = "anti")
  expect_equal(join_anti, 'dplyr::anti_join(patients, visits, by = c("patient_id" = "subject_id"))')
  expect_silent(parse(text = join_anti))

  join_pipe <- sv_code_join("patients", "visits", "patient_id", "subject_id", join_type = "left", pipe = TRUE)
  expect_equal(join_pipe, 'patients %>% dplyr::left_join(visits, by = c("patient_id" = "subject_id"))')
  expect_silent(parse(text = join_pipe))

  # 2. Renames: syntactic, non-syntactic, multiple, piped
  rename_std <- sv_code_rename("patients", "patient_id", "subject_id")
  expect_equal(rename_std, "dplyr::rename(patients, subject_id = patient_id)")
  expect_silent(parse(text = rename_std))

  rename_special <- sv_code_rename("clinical data", "Blood Pressure (mmHg)", "systolic_bp")
  expect_equal(rename_special, "dplyr::rename(`clinical data`, systolic_bp = `Blood Pressure (mmHg)`)")
  expect_silent(parse(text = rename_special))

  rename_multi <- sv_code_rename("patients", c("weight_kg", "height_cm"), c("weight", "height"), pipe = TRUE)
  expect_equal(rename_multi, "patients %>% dplyr::rename(weight = weight_kg, height = height_cm)")
  expect_silent(parse(text = rename_multi))

  # 3. Mutates: simple, multi-column expression, piped
  mutate_bmi <- sv_code_mutate("patients", "bmi", "weight_kg / ((height_cm / 100) ^ 2)")
  expect_equal(mutate_bmi, "dplyr::mutate(patients, bmi = weight_kg / ((height_cm / 100) ^ 2))")
  expect_silent(parse(text = mutate_bmi))

  mutate_pipe <- sv_code_mutate("visits", "hypertensive", "systolic_bp >= 130", pipe = TRUE)
  expect_equal(mutate_pipe, "visits %>% dplyr::mutate(hypertensive = systolic_bp >= 130)")
  expect_silent(parse(text = mutate_pipe))

  # 4. Filters & Selects
  filter_code <- sv_code_filter("patients", c("age >= 40", "gender_raw != 'Unknown'"), pipe = TRUE)
  expect_equal(filter_code, "patients %>% dplyr::filter(age >= 40, gender_raw != 'Unknown')")
  expect_silent(parse(text = filter_code))

  select_code <- sv_code_select("patients", c("patient_id", "age", "weight_kg"), pipe = TRUE)
  expect_equal(select_code, "patients %>% dplyr::select(patient_id, age, weight_kg)")
  expect_silent(parse(text = select_code))
})

test_that("e2e: categorical discrepancy detection and recoding pipeline", {
  raw_values <- c("Male", "Female", "M", "Fem", "Unknown", NA)
  std_values <- c("Male", "Female", "Other")

  discrepancies <- sv_detect_discrepancies(raw_values, std_values, max_distance = 3)

  # Check structure
  expect_type(discrepancies, "list")
  expect_setequal(discrepancies$exact_matches, c("Male", "Female"))
  expect_setequal(discrepancies$only_in_x, c("M", "Fem", "Unknown"))
  expect_setequal(discrepancies$only_in_y, "Other")

  # Fuzzy matches: "Fem" is close to "Female"
  expect_true(is.data.frame(discrepancies$fuzzy_matches))
  expect_true(any(discrepancies$fuzzy_matches$x == "Fem" & discrepancies$fuzzy_matches$y == "Female"))

  # Recoding via crosswalk data frame
  cw_df <- data.frame(
    from = c("M", "Fem", "Unknown"),
    to = c("Male", "Female", NA),
    stringsAsFactors = FALSE
  )

  # Case match recode
  recode_case <- sv_code_recode(
    "patients",
    col = "gender_raw",
    crosswalk = cw_df,
    method = "case_match",
    default = "gender_raw",
    pipe = TRUE
  )
  expect_silent(parse(text = recode_case))
  expect_true(grepl("dplyr::case_match", recode_case))
  expect_true(grepl('"M" ~ "Male"', recode_case))
  expect_true(grepl('"Fem" ~ "Female"', recode_case))
  expect_true(grepl('"Unknown" ~ NA', recode_case))
  expect_true(grepl("\\.default = gender_raw", recode_case))

  # Factor recode (fct_recode)
  cw_fct <- list("Male" = c("M", "male"), "Female" = c("Fem", "female"))
  recode_fct <- sv_code_recode(
    "patients",
    col = "gender_raw",
    crosswalk = cw_fct,
    method = "fct_recode",
    pipe = TRUE
  )
  expect_silent(parse(text = recode_fct))
  expect_true(grepl("forcats::fct_recode", recode_fct))

  # Test execution of recode code on a concrete data frame
  test_df <- data.frame(gender_raw = c("Male", "Fem", "M", "Unknown"), stringsAsFactors = FALSE)
  env <- new.env(parent = asNamespace("dplyr"))
  env$patients <- test_df
  env$library <- library
  env[["%>%"]] <- dplyr::`%>%`
  res_recode <- eval(parse(text = recode_case), envir = env)
  expect_true("gender_raw" %in% colnames(res_recode))
  expect_equal(res_recode$gender_raw, c("Male", "Female", "Male", NA_character_))
})

test_that("e2e: LLM schema synthesis, prompt construction, and code extraction", {
  patients_df <- data.frame(
    patient_id = paste0("ID_", 1:20), # 20 subjects
    age = seq(30, 68, length.out = 20),
    weight_kg = seq(50, 95, length.out = 20),
    stringsAsFactors = FALSE
  )
  visits_tbl <- dplyr::tibble(
    subject_id = paste0("ID_", 1:20),
    systolic_bp = seq(110, 150, length.out = 20)
  )

  c_df <- sv_normalize(patients_df, name = "patients")
  c_tbl <- sv_normalize(visits_tbl, name = "visits")

  # 1. Build schema context across multiple tables with max_categories = 5
  schema_ctx <- sv_build_schema_context(list(c_df, c_tbl), max_categories = 5L)
  expect_type(schema_ctx, "character")
  expect_true(grepl("patients", schema_ctx))
  expect_true(grepl("visits", schema_ctx))
  expect_true(grepl("patient_id", schema_ctx))
  expect_true(grepl("subject_id", schema_ctx))
  expect_true(grepl("systolic_bp", schema_ctx))
  expect_true(grepl("20 unique values", schema_ctx))

  # Truncation check: ID_20 is truncated and not dumped
  expect_false(grepl("ID_20", schema_ctx))

  # 2. Build system and user prompt bundle
  prompt_bundle <- sv_build_prompt(
    user_prompt = "Join patients and visits, then calculate mean systolic_bp by age bracket",
    schema_context = schema_ctx
  )
  expect_type(prompt_bundle, "list")
  expect_true(any(c("system_message", "system") %in% names(prompt_bundle)))
  expect_true(any(c("user_message", "user") %in% names(prompt_bundle)))

  sys_msg <- if ("system_message" %in% names(prompt_bundle)) prompt_bundle$system_message else prompt_bundle$system
  usr_msg <- if ("user_message" %in% names(prompt_bundle)) prompt_bundle$user_message else prompt_bundle$user

  expect_true(grepl("tidyverse|dplyr", sys_msg, ignore.case = TRUE))
  expect_true(grepl("Join patients and visits", usr_msg))
  expect_true(grepl("patients", usr_msg))

  # 3. Extract code from simulated LLM response
  simulated_response <- paste0(
    "Sure! Here is the clean tidyverse pipeline to join and calculate mean BP:\n\n",
    "```r\n",
    "result <- patients |>\n",
    "  dplyr::left_join(visits, by = c(\"patient_id\" = \"subject_id\")) |>\n",
    "  dplyr::mutate(age_group = dplyr::if_else(age >= 50, \"50+\", \"<50\")) |>\n",
    "  dplyr::group_by(age_group) |>\n",
    "  dplyr::summarise(mean_bp = mean(systolic_bp, na.rm = TRUE))\n",
    "```\n\n",
    "You can run this directly in your active R session."
  )

  extracted_code <- sv_extract_code(simulated_response)
  expect_false(grepl("```", extracted_code))
  expect_true(grepl("dplyr::left_join", extracted_code))
  expect_silent(parse(text = extracted_code))

  # 4. Mock sv_call_llm for Ollama and OpenAI backends using httr2::with_mocked_responses
  mock_ollama_resp <- function(req) {
    resp_payload <- list(
      model = "llama3.2",
      message = list(role = "assistant", content = "```r\nres <- 1 + 1\n```"),
      done = TRUE
    )
    httr2::response(
      status_code = 200L,
      headers = list("content-type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(resp_payload, auto_unbox = TRUE))
    )
  }

  httr2::with_mocked_responses(mock_ollama_resp, {
    code_ollama <- sv_call_llm(
      prompt = "Test Ollama",
      backend = "ollama",
      extract_code = TRUE
    )
    expect_equal(code_ollama, "res <- 1 + 1")
    expect_silent(parse(text = code_ollama))
  })

  mock_openai_resp <- function(req) {
    resp_payload <- list(
      id = "chatcmpl-test",
      choices = list(list(message = list(role = "assistant", content = "```r\nres <- 2 * 2\n```")))
    )
    httr2::response(
      status_code = 200L,
      headers = list("content-type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(resp_payload, auto_unbox = TRUE))
    )
  }

  httr2::with_mocked_responses(mock_openai_resp, {
    code_openai <- sv_call_llm(
      prompt = "Test OpenAI",
      backend = "openai",
      api_key = "test-sk",
      extract_code = TRUE
    )
    expect_equal(code_openai, "res <- 2 * 2")
    expect_silent(parse(text = code_openai))
  })
})

test_that("e2e: RStudio code delivery and console fallback", {
  test_code <- "df <- data.frame(a = 1:5) %>% dplyr::mutate(b = a * 10)"

  # 1. Fallback mode (when RStudio is not running)
  testthat::with_mocked_bindings(
    isAvailable = function(...) FALSE,
    .package = "rstudioapi",
    code = {
      res_insert_headless <- sv_insert_code(test_code)
      expect_type(res_insert_headless, "list")
      expect_false(res_insert_headless$success)
      expect_equal(res_insert_headless$destination, "fallback")
      expect_equal(res_insert_headless$code, test_code)

      res_send_headless <- sv_send_to_console(test_code, execute = FALSE)
      expect_type(res_send_headless, "list")
      expect_false(res_send_headless$success)
      expect_equal(res_send_headless$destination, "fallback")
    }
  )

  # 2. Mocked RStudio environment with active document context
  inserted_text <- NULL
  sent_to_console <- NULL

  testthat::with_mocked_bindings(
    isAvailable = function(...) TRUE,
    getActiveDocumentContext = function(...) list(id = "doc_e2e", path = "e2e_script.R"),
    insertText = function(text, ...) {
      inserted_text <<- text
      invisible(TRUE)
    },
    sendToConsole = function(code, execute = TRUE, ...) {
      sent_to_console <<- list(code = code, execute = execute)
      invisible(TRUE)
    },
    .package = "rstudioapi",
    code = {
      expect_true(sv_is_rstudio_available())

      res_ins <- sv_insert_code(test_code)
      expect_true(res_ins$success)
      expect_equal(res_ins$destination, "editor")
      expect_equal(inserted_text, test_code)

      res_snd <- sv_send_to_console(test_code, execute = TRUE)
      expect_true(res_snd$success)
      expect_equal(res_snd$destination, "console")
      expect_equal(sent_to_console$code, test_code)
      expect_true(sent_to_console$execute)
    }
  )
})

test_that("e2e: HTML widget creation, Shiny rendering, and standalone HTML export", {
  df1 <- data.frame(id = 1:5, drug = c("A", "B", "A", "C", "B"), dose = c(10, 20, 15, 30, 25), stringsAsFactors = FALSE)
  df2 <- data.frame(drug_id = c("A", "B", "C"), name = c("Alpha", "Beta", "Gamma"), stringsAsFactors = FALSE)
  tbl <- table(df1$drug)

  # 1. Create sideview_widget from multiple heterogeneous objects
  widget <- sideview_widget(
    patients = df1,
    lookup = df2,
    frequencies = tbl,
    options = list(theme = "light", zoom = 1.0)
  )

  expect_s3_class(widget, "sideview")
  expect_s3_class(widget, "htmlwidget")
  expect_equal(length(widget$x$cards), 3L)
  expect_equal(widget$x$cards[[1]]$name, "patients")
  expect_equal(widget$x$cards[[2]]$name, "lookup")
  expect_equal(widget$x$cards[[3]]$name, "frequencies")

  # 2. Test Shiny UI and output integration
  ui_widget <- sideviewOutput("sideview_e2e_id", width = "100%", height = "600px")
  expect_true(inherits(ui_widget, "shiny.tag") || inherits(ui_widget, "shiny.tag.list"))
  html_ui_str <- as.character(ui_widget)
  expect_true(grepl("sideview_e2e_id", html_ui_str))
  expect_true(grepl("html-widget", html_ui_str))

  render_fn <- renderSideview({
    widget
  })
  expect_true(is.function(render_fn))
  expect_s3_class(render_fn, "shiny.render.function")

  # 3. Export to standalone selfcontained HTML file on disk
  tf <- tempfile(fileext = ".html")
  on.exit(if (file.exists(tf)) unlink(tf), add = TRUE)

  saved_path <- save_sideview(widget, file = tf, selfcontained = TRUE, title = "E2E Integration Report")

  expect_true(file.exists(tf))
  expect_equal(saved_path, normalizePath(tf, winslash = "/", mustWork = FALSE))

  file_size <- file.info(tf)$size
  expect_true(file_size > 2000L) # Non-trivial bundle

  html_content <- paste(readLines(tf, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl("E2E Integration Report", html_content))
  expect_true(grepl("sideview", html_content, ignore.case = TRUE))
  expect_true(grepl("patients", html_content))
  expect_true(grepl("lookup", html_content))
  expect_true(grepl("frequencies", html_content))
  expect_true(grepl("htmlwidget", html_content, ignore.case = TRUE))
})

test_that("e2e: complete multi-table clinical data workflow execution and data verification", {
  # Full simulated user story:
  # Ingest 2 clinical tables with mismatched IDs, typos in gender, and compute BMI
  demographics_raw <- data.frame(
    subject_code = c("SUBJ_01", "SUBJ_02", "SUBJ_03", "SUBJ_04"),
    dob = as.Date(c("1980-05-12", "1972-11-03", "1995-02-28", "1963-08-19")),
    sex_entry = c("Male", "Female", "M", "Fem"),
    height_cm = c(180, 165, 175, 160),
    stringsAsFactors = FALSE
  )

  vitals_raw <- dplyr::tibble(
    patient_id = c("SUBJ_01", "SUBJ_02", "SUBJ_03", "SUBJ_05"),
    weight_kg = c(82, 65, 78, 92),
    systolic_bp = c(122, 138, 118, 142)
  )

  # Step A: Normalize tables
  card_demo <- sv_normalize(demographics_raw, name = "demographics")
  card_vitals <- sv_normalize(vitals_raw, name = "vitals")

  expect_equal(card_demo$dims, c(4L, 4L))
  expect_equal(card_vitals$dims, c(4L, 3L))

  # Step B: Detect discrepancies in categorical values
  discrepancies <- sv_detect_discrepancies(
    demographics_raw$sex_entry,
    c("Male", "Female"),
    max_distance = 3
  )
  expect_setequal(discrepancies$only_in_x, c("M", "Fem"))

  # Step C: Generate recode transformation
  crosswalk <- data.frame(from = c("M", "Fem"), to = c("Male", "Female"), stringsAsFactors = FALSE)
  code_recode <- sv_code_recode(
    "demographics",
    col = "sex_entry",
    crosswalk = crosswalk,
    method = "case_match",
    default = "sex_entry",
    pipe = TRUE
  )
  expect_silent(parse(text = code_recode))

  # Step D: Generate rename
  code_rename <- sv_code_rename("demographics", "dob", "birth_date", pipe = TRUE)
  expect_silent(parse(text = code_rename))

  # Step E: Generate join between demographics and vitals
  code_join <- sv_code_join("demographics", "vitals", "subject_code", "patient_id", join_type = "left", pipe = TRUE)
  expect_silent(parse(text = code_join))

  # Step F: Generate mutate for BMI
  code_mutate <- sv_code_mutate("joined_df", "bmi", "round(weight_kg / ((height_cm / 100) ^ 2), 1)", pipe = TRUE)
  expect_silent(parse(text = code_mutate))

  # Step G: Synthesize the full end-to-end R script and execute it
  full_script <- paste(
    "library(dplyr)",
    "transformed_data <- demographics %>%",
    "  dplyr::mutate(sex_entry = dplyr::case_match(sex_entry, 'M' ~ 'Male', 'Fem' ~ 'Female', .default = sex_entry)) %>%",
    "  dplyr::rename(birth_date = dob) %>%",
    "  dplyr::left_join(vitals, by = c('subject_code' = 'patient_id')) %>%",
    "  dplyr::mutate(bmi = round(weight_kg / ((height_cm / 100) ^ 2), 1)) %>%",
    "  dplyr::filter(!is.na(bmi)) %>%",
    "  dplyr::select(subject_code, birth_date, sex_entry, height_cm, weight_kg, systolic_bp, bmi)",
    sep = "\n"
  )

  # Check zero syntax errors in full script
  parsed_script <- parse(text = full_script)
  expect_true(is.expression(parsed_script))

  # Evaluate full script in a controlled environment
  test_env <- new.env(parent = asNamespace("dplyr"))
  test_env$demographics <- demographics_raw
  test_env$vitals <- vitals_raw
  test_env$library <- library
  test_env$round <- round
  test_env[["%>%"]] <- dplyr::`%>%`

  eval(parsed_script, envir = test_env)
  res_table <- test_env$transformed_data

  expect_s3_class(res_table, "data.frame")
  expect_equal(nrow(res_table), 3L) # SUBJ_01, SUBJ_02, SUBJ_03 have vitals
  expect_equal(colnames(res_table), c("subject_code", "birth_date", "sex_entry", "height_cm", "weight_kg", "systolic_bp", "bmi"))
  expect_equal(res_table$sex_entry, c("Male", "Female", "Male")) # "M" recoded to "Male"
  expect_equal(res_table$bmi[1], round(82 / (1.80^2), 1)) # 25.3
  expect_equal(res_table$bmi[2], round(65 / (1.65^2), 1)) # 23.9
  expect_equal(res_table$bmi[3], round(78 / (1.75^2), 1)) # 25.5
})
