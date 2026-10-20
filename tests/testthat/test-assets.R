# Source R files if running standalone
if (!"package:sideview" %in% search()) {
  r_files <- list.files(c("R", "../R", "../../R"), pattern = "\\.[Rr]$", full.names = TRUE)
  for (f in r_files) source(f)
}

find_asset <- function(filename) {
  candidates <- c(
    file.path("inst", "www", filename),
    file.path("..", "inst", "www", filename),
    file.path("..", "..", "inst", "www", filename),
    system.file("www", filename, package = "sideview")
  )
  for (c in candidates) {
    if (nzchar(c) && file.exists(c)) {
      return(normalizePath(c))
    }
  }
  # Return expected path for clear assertion failures
  file.path("inst", "www", filename)
}

read_asset <- function(filename) {
  path <- find_asset(filename)
  if (!file.exists(path)) return("")
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

test_that("all required web asset files exist and are non-empty", {
  required_files <- c("panzoom.min.js", "sideview.css", "sideview.js")
  for (f in required_files) {
    path <- find_asset(f)
    expect_true(file.exists(path), info = paste("Asset missing:", f, "at", path))
    info <- file.info(path)
    expect_gt(info$size, 0, label = paste("Asset file size of", f))
  }
})

test_that("sideview.css contains all required CSS selectors and styles", {
  css <- read_asset("sideview.css")
  expect_gt(nchar(css), 100, label = "sideview.css length")

  # Infinite canvas & panzoom viewport
  expect_match(css, "\\.sideview-canvas", info = "sideview.css must contain .sideview-canvas")
  expect_match(css, "overflow|transform|perspective", info = "canvas must configure viewport/overflow/transforms")

  # Draggable table cards
  expect_match(css, "\\.sideview-card", info = "sideview.css must contain .sideview-card")
  expect_match(css, "\\.sideview-card-header", info = "sideview.css must contain .sideview-card-header")
  expect_match(css, "\\.sideview-card-body", info = "sideview.css must contain .sideview-card-body")

  # Scrollable tables, sticky headers, cell highlight classes
  expect_match(css, "\\.sideview-table", info = "sideview.css must contain .sideview-table")
  expect_match(css, "position:\\s*sticky|sticky", info = "table must support sticky headers")
  expect_match(css, "highlight|\\.sv-highlight|\\.sideview-cell-highlight", info = "table must have highlight classes")

  # SVG spline overlay for field mapping
  expect_match(css, "\\.sideview-connector-svg", info = "sideview.css must contain .sideview-connector-svg")

  # Action drawer for join, mutate, recode, discrepancy
  expect_match(css, "\\.sideview-drawer", info = "sideview.css must contain .sideview-drawer")

  # Floating natural language AI prompt bar
  expect_match(css, "\\.sideview-ai-bar", info = "sideview.css must contain .sideview-ai-bar")

  # Color highlighter swatches palette
  expect_match(css, "\\.sideview-palette", info = "sideview.css must contain .sideview-palette")

  # Modern CSS custom properties (variables)
  expect_match(css, "--sv-|--sideview-", info = "sideview.css must use CSS custom properties")
})

test_that("sideview.js contains required functions, event handlers, and Shiny integration", {
  js <- read_asset("sideview.js")
  expect_gt(nchar(js), 500, label = "sideview.js length")

  # initSideview()
  expect_match(js, "function\\s+initSideview|initSideview\\s*=|window\\.initSideview", 
               info = "sideview.js must define or export initSideview")

  # Panzoom wheel zoom and pan handling
  expect_match(js, "wheel|zoom|pan|Panzoom|panzoom", 
               info = "sideview.js must handle panzoom wheel zoom and pan")

  # Table card drag and drop handling with snap-to-edge
  expect_match(js, "drag|mousedown|mousemove|mouseup|pointerdown|pointermove|pointerup", 
               info = "sideview.js must handle card dragging")
  expect_match(js, "snap|threshold|dock|snap-to-edge|snapToEdge", 
               info = "sideview.js must implement snap-to-edge logic")

  # Independent table scrolling and synchronized scroll sync
  expect_match(js, "scroll|sync|scrollSync|syncScroll", 
               info = "sideview.js must implement table scrolling and sync scroll")

  # Cell/column color highlighting
  expect_match(js, "highlight|palette|color", 
               info = "sideview.js must handle cell/column color highlighting")

  # Click-to-connect field mapping with SVG bezier curves
  expect_match(js, "connector|bezier|path|M.*C|curve|connect", 
               info = "sideview.js must draw SVG bezier curves for field connections")

  # Inline column renaming
  expect_match(js, "rename|dblclick|contenteditable|prompt|renameColumn", 
               info = "sideview.js must support inline column renaming")

  # Shiny.setInputValue integration
  expect_match(js, "Shiny\\.setInputValue", 
               info = "sideview.js must integrate Shiny.setInputValue for event dispatch")
})

test_that("panzoom.min.js contains a valid Panzoom library implementation", {
  pz <- read_asset("panzoom.min.js")
  expect_gt(nchar(pz), 200, label = "panzoom.min.js length")
  expect_match(pz, "panzoom|Panzoom|transform|matrix|zoom", 
               info = "panzoom.min.js must contain Panzoom library functionality")
})
