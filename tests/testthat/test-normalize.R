# Source R files if running standalone without package installed
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

test_that("data.frame and tibble normalization works", {
  df <- data.frame(
    id = 1:3,
    name = c("Alice", "Bob", "Charlie"),
    stringsAsFactors = FALSE
  )
  
  card <- sv_normalize(df, name = "users", id = "card_users")
  
  expect_s3_class(card, "sideview_card")
  expect_equal(card$id, "card_users")
  expect_equal(card$name, "users")
  expect_equal(card$type, "grid")
  expect_equal(nrow(card$data), 3)
  expect_equal(ncol(card$data), 2)
  expect_equal(card$dims, c(3L, 2L))
  expect_equal(names(card$col_types), c("id", "name"))
  expect_equal(unname(card$col_types["id"]), "integer")
  expect_equal(unname(card$col_types["name"]), "character")

  # Test tibble
  tbl <- dplyr::tibble(
    x = c(1.5, 2.5),
    y = c(TRUE, FALSE)
  )
  card_tbl <- sv_normalize(tbl, name = "my_tibble")
  expect_s3_class(card_tbl, "sideview_card")
  expect_equal(card_tbl$name, "my_tibble")
  expect_equal(card_tbl$type, "grid")
  expect_equal(card_tbl$dims, c(2L, 2L))
  expect_true(nchar(card_tbl$id) > 0)
})

test_that("base::table normalization converts to data.frame grid", {
  # 1D table
  tbl_1d <- table(c("apple", "banana", "apple", "cherry"))
  card_1d <- sv_normalize(tbl_1d, name = "fruits")
  
  expect_s3_class(card_1d, "sideview_card")
  expect_equal(card_1d$name, "fruits")
  expect_equal(card_1d$type, "grid")
  expect_true(is.data.frame(card_1d$data))
  expect_equal(ncol(card_1d$data), 2) # Var1, Freq
  expect_equal(card_1d$dims, c(3L, 2L))
  
  # 2D table
  tbl_2d <- table(c("A", "A", "B"), c("X", "Y", "X"))
  card_2d <- sv_normalize(tbl_2d, name = "crosstab")
  expect_s3_class(card_2d, "sideview_card")
  expect_equal(card_2d$type, "grid")
  expect_equal(ncol(card_2d$data), 3) # Var1, Var2, Freq
  expect_equal(card_2d$dims, c(4L, 3L))
})

test_that("gt_tbl normalization renders HTML and retains underlying data", {
  skip_if_not_installed("gt")
  
  gt_obj <- gt::gt(head(mtcars, 4)[, c("mpg", "cyl", "hp")])
  card_gt <- sv_normalize(gt_obj, name = "gt_cars")
  
  expect_s3_class(card_gt, "sideview_card")
  expect_equal(card_gt$name, "gt_cars")
  expect_equal(card_gt$type, "html")
  expect_true(is.character(card_gt$html_content))
  expect_true(grepl("<table", card_gt$html_content))
  expect_equal(nrow(card_gt$data), 4)
  expect_equal(ncol(card_gt$data), 3)
  expect_equal(card_gt$dims, c(4L, 3L))
})

test_that("flextable normalization renders HTML and retains dataset", {
  skip_if_not_installed("flextable")
  
  ft_obj <- flextable::flextable(head(iris, 5)[, 1:3])
  card_ft <- sv_normalize(ft_obj, name = "ft_iris")
  
  expect_s3_class(card_ft, "sideview_card")
  expect_equal(card_ft$name, "ft_iris")
  expect_equal(card_ft$type, "html")
  expect_true(is.character(card_ft$html_content))
  expect_true(nchar(card_ft$html_content) > 0)
  expect_equal(nrow(card_ft$data), 5)
  expect_equal(ncol(card_ft$data), 3)
  expect_equal(card_ft$dims, c(5L, 3L))
})

test_that("htmlwidget normalization wraps widget container", {
  skip_if_not_installed("htmlwidgets")
  
  widget <- htmlwidgets::createWidget(
    name = "dummyWidget",
    x = list(values = 1:5),
    width = 400,
    height = 300
  )
  
  card_widget <- sv_normalize(widget, name = "my_widget")
  
  expect_s3_class(card_widget, "sideview_card")
  expect_equal(card_widget$name, "my_widget")
  expect_equal(card_widget$type, "widget")
  expect_s3_class(card_widget$widget, "htmlwidget")
})

test_that("sv_normalize handles unsupported types with error", {
  expect_error(
    sv_normalize(function(x) x),
    "Cannot normalize object"
  )
})
