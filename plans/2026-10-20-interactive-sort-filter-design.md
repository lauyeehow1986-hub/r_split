# Interactive Column Sorting and Filtering Design

**Date:** 2026-10-20  
**Status:** Approved  
**Package:** `sideview`

---

## 1. Overview
Users need the ability to visually sort and filter individual columns directly on the multi-table 2D canvas by clicking on table headers, with automatic generation of corresponding `dplyr::arrange()` and `dplyr::filter()` code in the Action Drawer.

---

## 2. Architecture & Components

### 2.1 Backend Code Generation (`R/codegen.R`)
* Export `sv_code_arrange(df_name, col, desc = FALSE, pipe = FALSE)`:
  - Generates `df %>% dplyr::arrange(col)` or `df %>% dplyr::arrange(dplyr::desc(col))`.
  - Supports multiple columns.
  - Validates inputs and handles backtick escaping via `sv_escape_ident()`.
* Utilize existing `sv_code_filter(df_name, condition, pipe = FALSE)`:
  - Generates `df %>% dplyr::filter(condition)`.

### 2.2 Client-Side Interactive Controls (`inst/www/`)
* **Header Icons in `.col-header-wrap`**:
  - `.sideview-sort-btn`: Tri-state button cycling `none` (`⇅`), `asc` (`▲`), and `desc` (`▼`).
  - `.sideview-filter-btn`: Popover toggle icon (`🔍`). Highlights blue when a filter is active on the column.
* **Client-Side Sorting Engine**:
  - Sorts DOM `<tr>` rows in `.sideview-table tbody` based on data type (numeric, date, or case-insensitive string).
  - Restores original row order when cycled back to `none`.
  - Updates drawer code to `dplyr::arrange(...)`.
* **Client-Side Filtering Popover**:
  - Positioned relative to the target column header.
  - Operators:
    - Numeric/Date: `>`, `>=`, `<`, `<=`, `==`, `!=`
    - Text: `contains`, `equals`, `starts_with`, `!=`
  - Instant client-side DOM row filtering (hiding non-matching rows).
  - Updates card header badge with filtered count (e.g. `2 / 4 rows`).
  - Updates drawer code to `dplyr::filter(...)`.
* **Action Drawer Tabs**:
  - Add `Filter` and `Arrange` tabs to `.sideview-drawer-tabs`.
  - Supports existing `Insert Script`, `Run & Exit`, `Run in R`, `Run Console`, `Copy`, and `Clear`.
  - `Clear` resets all active filters and sort orders.

### 2.3 Server Reactivity (`R/app_server.R`)
* Event observers for `column_sorted` and `column_filtered`.
* Dispatches `sideview_code_update` with the generated tidyverse pipeline.

---

## 3. Verification Plan
* Unit tests in `tests/testthat/test-codegen.R` for `sv_code_arrange`.
* Asset tests in `tests/testthat/test-assets.R` for sort/filter icons and popovers.
* Server tests in `tests/testthat/test-app.R` for Shiny event dispatch.
* Full testthat test suite (all tests passing).
