# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

test_that("sv_escape_ident escapes non-syntactic names properly", {
  expect_equal(sv_escape_ident("var1"), "var1")
  expect_equal(sv_escape_ident("var 1"), "`var 1`")
  expect_equal(sv_escape_ident("2024_year"), "`2024_year`")
  expect_equal(sv_escape_ident("data-set"), "`data-set`")
  expect_equal(sv_escape_ident("for"), "`for`")
  expect_equal(sv_escape_ident("TRUE"), "`TRUE`")
  expect_equal(sv_escape_ident("`already_backticked`"), "`already_backticked`")
  expect_equal(sv_escape_ident(character(0)), character(0))
})

test_that("sv_code_rename generates valid rename code with escaping", {
  # Standard column names
  code1 <- sv_code_rename("my_df", "old_col", "new_col")
  expect_equal(code1, "dplyr::rename(my_df, new_col = old_col)")
  expect_silent(parse(text = code1))

  # Non-syntactic column names and table names
  code2 <- sv_code_rename("my df", "old col", "new col")
  expect_equal(code2, "dplyr::rename(`my df`, `new col` = `old col`)")
  expect_silent(parse(text = code2))

  # Multiple columns
  code3 <- sv_code_rename("df", c("a", "b"), c("x", "y"))
  expect_equal(code3, "dplyr::rename(df, x = a, y = b)")
  expect_silent(parse(text = code3))

  # Pipe support
  code4 <- sv_code_rename("df", "old", "new", pipe = TRUE)
  expect_equal(code4, "df %>% dplyr::rename(new = old)")
  expect_silent(parse(text = code4))
})

test_that("sv_code_join generates valid join code across join types and formats by", {
  # left_join with differing column names
  code1 <- sv_code_join("patients", "visits", "patient_id", "subject_id", join_type = "left")
  expect_equal(code1, 'dplyr::left_join(patients, visits, by = c("patient_id" = "subject_id"))')
  expect_silent(parse(text = code1))

  # left_join with matching column names
  code2 <- sv_code_join("patients", "visits", "patient_id", "patient_id", join_type = "left")
  expect_equal(code2, 'dplyr::left_join(patients, visits, by = "patient_id")')
  expect_silent(parse(text = code2))

  # All join types: inner, anti, right, full, semi
  expect_match(sv_code_join("a", "b", "id", "id", join_type = "inner"), "^dplyr::inner_join")
  expect_match(sv_code_join("a", "b", "id", "id", join_type = "anti"), "^dplyr::anti_join")
  expect_match(sv_code_join("a", "b", "id", "id", join_type = "right"), "^dplyr::right_join")
  expect_match(sv_code_join("a", "b", "id", "id", join_type = "full"), "^dplyr::full_join")
  expect_match(sv_code_join("a", "b", "id", "id", join_type = "semi"), "^dplyr::semi_join")

  # Table and column names with spaces or symbols
  code3 <- sv_code_join("table 1", "table 2", "patient id", "subject id")
  expect_equal(code3, 'dplyr::left_join(`table 1`, `table 2`, by = c("patient id" = "subject id"))')
  expect_silent(parse(text = code3))

  # Pipe support
  code4 <- sv_code_join("patients", "visits", "id", "id", pipe = TRUE)
  expect_equal(code4, 'patients %>% dplyr::left_join(visits, by = "id")')
  expect_silent(parse(text = code4))

  # Error on invalid join type
  expect_error(sv_code_join("a", "b", "id", "id", join_type = "cross_product"), "Unsupported join_type")
})

test_that("sv_code_join supports composite multi-key joins", {
  code <- sv_code_join("patients", "visits", 
                       col1 = c("patient_id", "site_id"), 
                       col2 = c("patient_id", "hospital_id"), 
                       pipe = TRUE)
  expect_match(code, 'patients\\s*%>%\\s*dplyr::left_join\\(visits,\\s*by\\s*=\\s*c\\("patient_id"\\s*=\\s*"patient_id",\\s*"site_id"\\s*=\\s*"hospital_id"\\)\\)')
  expect_silent(parse(text = code))

  # Identical vector keys
  code_ident <- sv_code_join("df1", "df2", col1 = c("a", "b"), col2 = c("a", "b"), pipe = TRUE)
  expect_equal(code_ident, 'df1 %>% dplyr::left_join(df2, by = c("a", "b"))')
  expect_silent(parse(text = code_ident))

  # col2 defaults to col1 for vector
  code_default <- sv_code_join("df1", "df2", col1 = c("a", "b"), pipe = TRUE)
  expect_equal(code_default, 'df1 %>% dplyr::left_join(df2, by = c("a", "b"))')
  expect_silent(parse(text = code_default))

  # List representation of multi-keys (as passed from Shiny WebSocket JSON)
  code_list <- sv_code_join("df1", "df2", col1 = list("a", "b"), col2 = list("x", "y"), pipe = TRUE)
  expect_equal(code_list, 'df1 %>% dplyr::left_join(df2, by = c("a" = "x", "b" = "y"))')
  expect_silent(parse(text = code_list))

  code_list_same <- sv_code_join("df1", "df2", col1 = list("a", "b"), col2 = list("a", "b"), pipe = TRUE)
  expect_equal(code_list_same, 'df1 %>% dplyr::left_join(df2, by = c("a", "b"))')
  expect_silent(parse(text = code_list_same))

  # Backtick-wrapped identifiers are stripped inside by = c("col" = "col")
  code_backtick <- sv_code_join("df1", "df2", col1 = c("`col a`", "`col b`"), col2 = c("`col a`", "`col c`"), pipe = TRUE)
  expect_equal(code_backtick, 'df1 %>% dplyr::left_join(df2, by = c("col a" = "col a", "col b" = "col c"))')
  expect_silent(parse(text = code_backtick))
})

test_that("sv_code_join generates intermediate piped join segments when df1 is NULL", {
  code_pipe_null <- sv_code_join(NULL, "df2", "id", pipe = TRUE)
  expect_equal(code_pipe_null, 'dplyr::left_join(df2, by = "id")')

  code_nonpipe_null <- sv_code_join(NULL, "df2", "id", pipe = FALSE)
  expect_equal(code_nonpipe_null, 'dplyr::left_join(df2, by = "id")')

  # Multi-key intermediate segment
  code_multi_null <- sv_code_join(NULL, "df2", c("a", "b"), c("x", "y"), pipe = TRUE)
  expect_equal(code_multi_null, 'dplyr::left_join(df2, by = c("a" = "x", "b" = "y"))')
})

test_that("sv_code_join validates arguments and throws appropriate errors", {
  # Mismatched key lengths
  expect_error(
    sv_code_join("df1", "df2", col1 = c("a", "b"), col2 = "x"),
    "`col1` and `col2` must have the same length."
  )

  # Empty keys
  expect_error(
    sv_code_join("df1", "df2", col1 = character(0)),
    "Join columns \\(`col1` and `col2`\\) must not be empty."
  )
  expect_error(
    sv_code_join("df1", "df2", col1 = "a", col2 = character(0)),
    "Join columns \\(`col1` and `col2`\\) must not be empty."
  )

  # Invalid df2 (missing, NULL, NA, empty string, vector > 1)
  expect_error(sv_code_join("df1"), "Join table `df2` must be a single non-empty character string.")
  expect_error(sv_code_join("df1", NULL, "id"), "Join table `df2` must be a single non-empty character string.")
  expect_error(sv_code_join("df1", "", "id"), "Join table `df2` must be a single non-empty character string.")
  expect_error(sv_code_join("df1", NA_character_, "id"), "Join table `df2` must be a single non-empty character string.")
  expect_error(sv_code_join("df1", c("df2", "df3"), "id"), "Join table `df2` must be a single non-empty character string.")
})


test_that("sv_code_mutate generates valid mutate code", {
  # Single mutation
  code1 <- sv_code_mutate("df", "total", "price * quantity")
  expect_equal(code1, "dplyr::mutate(df, total = price * quantity)")
  expect_silent(parse(text = code1))

  # Non-syntactic column name
  code2 <- sv_code_mutate("my df", "total price", "price * quantity")
  expect_equal(code2, "dplyr::mutate(`my df`, `total price` = price * quantity)")
  expect_silent(parse(text = code2))

  # Multiple mutations
  code3 <- sv_code_mutate("df", c("a", "b"), c("1", "2"))
  expect_equal(code3, "dplyr::mutate(df, a = 1, b = 2)")
  expect_silent(parse(text = code3))

  # Pipe support
  code4 <- sv_code_mutate("df", "total", "price * quantity", pipe = TRUE)
  expect_equal(code4, "df %>% dplyr::mutate(total = price * quantity)")
  expect_silent(parse(text = code4))
})

test_that("sv_code_filter generates valid filter code", {
  # Single condition
  code1 <- sv_code_filter("df", "age >= 18")
  expect_equal(code1, "dplyr::filter(df, age >= 18)")
  expect_silent(parse(text = code1))

  # Multiple conditions
  code2 <- sv_code_filter("df", c("age >= 18", "status == 'Active'"))
  expect_equal(code2, "dplyr::filter(df, age >= 18, status == 'Active')")
  expect_silent(parse(text = code2))

  # Pipe support
  code3 <- sv_code_filter("df", "age >= 18", pipe = TRUE)
  expect_equal(code3, "df %>% dplyr::filter(age >= 18)")
  expect_silent(parse(text = code3))
})

test_that("sv_code_select generates valid select code", {
  # Multiple columns
  code1 <- sv_code_select("df", c("id", "name", "age"))
  expect_equal(code1, "dplyr::select(df, id, name, age)")
  expect_silent(parse(text = code1))

  # Columns with spaces
  code2 <- sv_code_select("df", c("first name", "last name"))
  expect_equal(code2, "dplyr::select(df, `first name`, `last name`)")
  expect_silent(parse(text = code2))

  # Pipe support
  code3 <- sv_code_select("df", c("id", "name"), pipe = TRUE)
  expect_equal(code3, "df %>% dplyr::select(id, name)")
  expect_silent(parse(text = code3))
})

test_that("sv_detect_discrepancies detects exact and fuzzy matches and discrepancies", {
  # Character input with exact matches, fuzzy matches, discrepancies, and NA
  x <- c("Male", "Female", "Mle", "Unknown", NA)
  y <- c("Male", "Female", "Other", NA)

  res <- sv_detect_discrepancies(x, y, max_distance = 2)

  expect_type(res, "list")
  expect_setequal(res$exact_matches, c("Male", "Female"))
  expect_setequal(res$only_in_x, c("Mle", "Unknown"))
  expect_setequal(res$only_in_y, "Other")

  # Fuzzy matches: "Mle" is distance 1 from "Male"
  expect_true(is.data.frame(res$fuzzy_matches))
  expect_equal(colnames(res$fuzzy_matches), c("x", "y", "distance"))
  expect_true(any(res$fuzzy_matches$x == "Mle" & res$fuzzy_matches$y == "Male"))
  expect_equal(res$fuzzy_matches$distance[res$fuzzy_matches$x == "Mle" & res$fuzzy_matches$y == "Male"], 1L)

  # Match statistics
  expect_equal(res$stats$exact_count, 2L)
  expect_equal(res$stats$na_x, 1L)
  expect_equal(res$stats$na_y, 1L)
  expect_equal(res$stats$only_x_count, 2L)
  expect_equal(res$stats$only_y_count, 1L)
  expect_equal(res$match_stats$exact_count, 2L)

  # Numeric input handling
  x_num <- c(100, 200, 305)
  y_num <- c(100, 200, 300)
  res_num <- sv_detect_discrepancies(x_num, y_num, max_distance = 1)
  expect_setequal(res_num$exact_matches, c("100", "200"))
  expect_equal(res_num$fuzzy_matches$x, "305")
  expect_equal(res_num$fuzzy_matches$y, "300")
  expect_equal(res_num$fuzzy_matches$distance, 1L)

  # Factor input handling
  x_fac <- factor(c("A", "B", "C"))
  y_fac <- factor(c("A", "B", "D"))
  res_fac <- sv_detect_discrepancies(x_fac, y_fac)
  expect_setequal(res_fac$exact_matches, c("A", "B"))
  expect_setequal(res_fac$only_in_x, "C")
  expect_setequal(res_fac$only_in_y, "D")

  # Empty and all-NA inputs
  res_empty <- sv_detect_discrepancies(character(0), character(0))
  expect_equal(length(res_empty$exact_matches), 0L)
  expect_equal(nrow(res_empty$fuzzy_matches), 0L)
  expect_equal(res_empty$stats$exact_count, 0L)

  res_all_na <- sv_detect_discrepancies(c(NA, NA), c(NA))
  expect_equal(length(res_all_na$exact_matches), 0L)
  expect_equal(res_all_na$stats$na_x, 2L)
  expect_equal(res_all_na$stats$na_y, 1L)
})

test_that("sv_code_recode generates case_match and fct_recode tidyverse code", {
  cw <- c("Compl." = "Completed", "completed" = "Completed", "InProg" = "In Progress")

  # case_match with default = NULL
  code1 <- sv_code_recode("df", "status", cw, method = "case_match")
  expect_true(grepl("dplyr::case_match", code1))
  expect_true(grepl('c\\("Compl.", "completed"\\) ~ "Completed"', code1) ||
              grepl('c\\("completed", "Compl."\\) ~ "Completed"', code1))
  expect_true(grepl('"InProg" ~ "In Progress"', code1))
  expect_false(grepl("\\.default", code1))
  expect_silent(parse(text = code1))

  # case_match preserving column as default
  code2 <- sv_code_recode("df", "status", cw, default = "status", method = "case_match")
  expect_true(grepl("\\.default = status", code2))
  expect_silent(parse(text = code2))

  # case_match with explicit literal default
  code3 <- sv_code_recode("df", "status", cw, default = "Unknown", method = "case_match")
  expect_true(grepl('\\.default = "Unknown"', code3))
  expect_silent(parse(text = code3))

  # case_match with pipe = TRUE
  code_pipe <- sv_code_recode("df", "status", cw, pipe = TRUE)
  expect_true(grepl("^df %>% dplyr::mutate", code_pipe))
  expect_silent(parse(text = code_pipe))

  # fct_recode method
  code_fct <- sv_code_recode("df", "status", cw, method = "fct_recode")
  expect_true(grepl("forcats::fct_recode", code_fct))
  expect_true(grepl('"Completed" = "Compl."', code_fct))
  expect_true(grepl('"Completed" = "completed"', code_fct))
  expect_true(grepl('"In Progress" = "InProg"', code_fct))
  expect_silent(parse(text = code_fct))

  # crosswalk provided as data.frame
  df_cw <- data.frame(from = c("Mle", "Femle"), to = c("Male", "Female"), stringsAsFactors = FALSE)
  code_df <- sv_code_recode("patients", "gender", df_cw)
  expect_true(grepl("dplyr::case_match", code_df))
  expect_true(grepl('"Mle" ~ "Male"', code_df))
  expect_true(grepl('"Femle" ~ "Female"', code_df))
  expect_silent(parse(text = code_df))

  # crosswalk provided as list
  list_cw <- list("Completed" = c("Compl.", "completed"), "In Progress" = "InProg")
  code_list <- sv_code_recode("df", "status", list_cw)
  expect_true(grepl('c\\("Compl.", "completed"\\) ~ "Completed"', code_list))
  expect_silent(parse(text = code_list))

  # crosswalk with NA targets (e.g. mapping "Unknown" to NA)
  cw_na <- data.frame(
    from = c("Compl.", "InProg", "Missing", "Unknown"),
    to = c("Completed", "In Progress", NA, NA),
    stringsAsFactors = FALSE
  )
  code_na <- sv_code_recode("df", "status", cw_na)
  expect_true(grepl('c\\("Missing", "Unknown"\\) ~ NA', code_na))
  expect_true(grepl('"Compl." ~ "Completed"', code_na))
  expect_false(grepl('NA_character_', code_na))
  expect_silent(parse(text = code_na))
})

test_that("codegen edge cases and defensive checks pass", {
  # Empty columns in rename
  expect_error(sv_code_rename("df", character(0), character(0)), "must not be empty")

  # Empty columns in join
  expect_error(sv_code_join("df1", "df2", character(0), character(0)), "must not be empty")

  # NA in max_distance for discrepancy detection
  res_na_dist <- sv_detect_discrepancies(c("apple", "banana"), c("aple", "berry"), max_distance = NA)
  expect_equal(res_na_dist$stats$exact_count, 0)
  expect_equal(nrow(res_na_dist$fuzzy_matches), 1)
  expect_equal(res_na_dist$fuzzy_matches$x, "apple")
  expect_equal(res_na_dist$fuzzy_matches$y, "aple")

  # Backtick escaping regex check
  expect_equal(sv_escape_ident("`already_escaped`"), "`already_escaped`")
  expect_equal(sv_escape_ident("needs escape"), "`needs escape`")
})


test_that("sv_code_arrange generates valid tidyverse arrange pipelines", {
  # Standard column ascending
  c1 <- sv_code_arrange("patients", "age", pipe = TRUE)
  expect_equal(c1, "patients %>% dplyr::arrange(age)")
  expect_silent(parse(text = c1))

  # Descending column
  c2 <- sv_code_arrange("patients", "age", desc = TRUE, pipe = TRUE)
  expect_equal(c2, "patients %>% dplyr::arrange(dplyr::desc(age))")
  expect_silent(parse(text = c2))

  # Prefix syntax without pipe
  c3 <- sv_code_arrange("patients", "age", desc = FALSE, pipe = FALSE)
  expect_equal(c3, "dplyr::arrange(patients, age)")
  expect_silent(parse(text = c3))

  # Non-syntactic column name
  c4 <- sv_code_arrange("patients", "bad column name", desc = TRUE, pipe = TRUE)
  expect_equal(c4, "patients %>% dplyr::arrange(dplyr::desc(`bad column name`))")
  expect_silent(parse(text = c4))

  # Multiple columns with mixed directions
  c5 <- sv_code_arrange("patients", c("age", "systolic bp"), desc = c(FALSE, TRUE), pipe = TRUE)
  expect_equal(c5, "patients %>% dplyr::arrange(age, dplyr::desc(`systolic bp`))")
  expect_silent(parse(text = c5))

  # Errors on empty column
  expect_error(sv_code_arrange("patients", character(0)), "must not be empty")
})
