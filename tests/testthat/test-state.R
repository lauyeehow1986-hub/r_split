# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

test_that("new_sideview_state creates valid sideview_state object", {
  state <- new_sideview_state()
  expect_s3_class(state, "sideview_state")
  expect_s3_class(state, "list")
  expect_equal(state$version, "0.2.0")
  expect_type(state$canvas, "list")
  expect_equal(state$canvas$zoom, 1)
  expect_equal(state$canvas$pan_x, 0)
  expect_equal(state$canvas$pan_y, 0)
  expect_true(is.list(state$cards))
  expect_equal(length(state$cards), 0)
  expect_true(is.list(state$connections))
  expect_equal(length(state$connections), 0)
  expect_type(state$pipeline, "list")
  expect_equal(state$pipeline$active_tab, "pipeline")
})

test_that("sv_save_state and sv_load_state roundtrip with JSON", {
  tf <- tempfile(fileext = ".json")
  on.exit(unlink(tf), add = TRUE)
  
  sample_state <- new_sideview_state(
    version = "0.2.0",
    canvas = list(zoom = 1.5, pan_x = 100.0, pan_y = -50.0),
    cards = list(
      list(
        id = "card_1",
        name = "orders",
        x = 50.0,
        y = 100.0,
        width = 400.0,
        height = 300.0,
        sorts = list(list(col = "order_date", dir = "desc")),
        filters = list(list(col = "status", op = "==", val = "completed"))
      ),
      list(
        id = "card_2",
        name = "customers",
        x = 500.0,
        y = 100.0,
        width = 380.0,
        height = 280.0,
        sorts = list(),
        filters = list()
      )
    ),
    connections = list(
      list(
        from_table = "orders",
        from_col = "customer_id",
        to_table = "customers",
        to_col = "id",
        join_type = "left_join"
      )
    ),
    pipeline = list(
      code = "orders %>% left_join(customers, by = c('customer_id' = 'id'))",
      active_tab = "pipeline"
    )
  )
  
  res <- sv_save_state(sample_state, tf)
  expect_equal(res, tf)
  expect_true(file.exists(tf))
  
  # Verify JSON content
  raw_txt <- readLines(tf, warn = FALSE)
  expect_true(any(grepl("\"version\": \"0.2.0\"", raw_txt) | grepl("\"version\":\\s*\"0.2.0\"", raw_txt)))
  
  # Load state
  loaded <- sv_load_state(tf)
  expect_s3_class(loaded, "sideview_state")
  expect_s3_class(loaded, "list")
  expect_equal(loaded$version, "0.2.0")
  expect_equal(loaded$canvas$zoom, 1.5)
  expect_equal(loaded$canvas$pan_x, 100.0)
  expect_equal(loaded$canvas$pan_y, -50.0)
  expect_equal(length(loaded$cards), 2)
  expect_equal(loaded$cards[[1]]$id, "card_1")
  expect_equal(loaded$cards[[1]]$name, "orders")
  expect_equal(loaded$cards[[1]]$x, 50.0)
  expect_equal(loaded$cards[[1]]$y, 100.0)
  expect_equal(loaded$cards[[1]]$width, 400.0)
  expect_equal(loaded$cards[[1]]$height, 300.0)
  expect_equal(loaded$cards[[1]]$sorts[[1]]$col, "order_date")
  expect_equal(loaded$cards[[1]]$filters[[1]]$val, "completed")
  expect_equal(length(loaded$connections), 1)
  expect_equal(loaded$connections[[1]]$from_table, "orders")
  expect_equal(loaded$connections[[1]]$to_table, "customers")
  expect_equal(loaded$connections[[1]]$join_type, "left_join")
  expect_equal(loaded$pipeline$active_tab, "pipeline")
  expect_equal(loaded$pipeline$code, sample_state$pipeline$code)
})

test_that("sv_save_state and sv_load_state roundtrip with RDS", {
  tf <- tempfile(fileext = ".rds")
  on.exit(unlink(tf), add = TRUE)
  
  sample_state <- new_sideview_state(
    version = "0.2.0",
    canvas = list(zoom = 0.8, pan_x = -200, pan_y = 120),
    cards = list(
      list(
        id = "card_a",
        name = "mtcars",
        x = 10,
        y = 20,
        width = 300,
        height = 200,
        sorts = list(),
        filters = list()
      )
    ),
    connections = list(),
    pipeline = list(code = "", active_tab = "pipeline")
  )
  
  res <- sv_save_state(sample_state, tf)
  expect_equal(res, tf)
  expect_true(file.exists(tf))
  
  loaded <- sv_load_state(tf)
  expect_s3_class(loaded, "sideview_state")
  expect_equal(loaded, sample_state)
})

test_that("sv_save_state supports explicit format argument", {
  tf_json <- tempfile(fileext = ".custom_json")
  tf_rds <- tempfile(fileext = ".custom_rds")
  on.exit(unlink(c(tf_json, tf_rds)), add = TRUE)
  
  st <- new_sideview_state()
  sv_save_state(st, tf_json, format = "json")
  sv_save_state(st, tf_rds, format = "rds")
  
  expect_true(file.exists(tf_json))
  expect_true(file.exists(tf_rds))
  
  # Loading custom extensions if format can be inferred or supported
  expect_error(sv_load_state(tf_json), "Invalid or unsupported")
  
  # Reading with fromJSON should work on tf_json
  parsed <- jsonlite::fromJSON(tf_json, simplifyVector = FALSE)
  expect_equal(parsed$version, "0.2.0")
})

test_that("sv_save_state and sv_load_state error handling", {
  st <- new_sideview_state()
  
  # Invalid format in save
  expect_error(sv_save_state(st, tempfile(), format = "xml"), "Invalid format")
  
  # Non-existent file in load
  expect_error(sv_load_state("non_existent_state_file_12345.json"), "does not exist")
  
  # Invalid extension in load
  tf_txt <- tempfile(fileext = ".txt")
  writeLines("hello", tf_txt)
  on.exit(unlink(tf_txt), add = TRUE)
  expect_error(sv_load_state(tf_txt), "Invalid or unsupported")
})

test_that("print.sideview_state displays clean summary", {
  st <- new_sideview_state(
    version = "0.2.0",
    canvas = list(zoom = 1.25, pan_x = 50, pan_y = -30),
    cards = list(
      list(id = "c1", name = "table1"),
      list(id = "c2", name = "table2")
    ),
    connections = list(
      list(from_table = "table1", from_col = "id", to_table = "table2", to_col = "id")
    )
  )
  
  out <- capture.output(print(st))
  expect_true(any(grepl("<sideview_state v0.2.0>", out)))
  expect_true(any(grepl("Cards:\\s*2", out)))
  expect_true(any(grepl("Connections:\\s*1", out)))
  expect_true(any(grepl("Canvas:", out)))
})

test_that("sv_load_state with launch=TRUE returns state when non-interactive", {
  tf <- tempfile(fileext = ".json")
  on.exit(unlink(tf), add = TRUE)
  
  st <- new_sideview_state()
  sv_save_state(st, tf)
  
  # In automated/testthat runs interactive() is FALSE
  res <- sv_load_state(tf, launch = TRUE)
  expect_s3_class(res, "sideview_state")
  expect_equal(res$version, "0.2.0")
})
