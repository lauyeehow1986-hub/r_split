# sideview Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `sideview` R package providing an infinite 2D canvas with mouse-wheel zoom for simultaneous multi-table viewing across all major R table formats (`tibble`, `data.frame`, `table`, `gt`, `flextable`, `htmlwidgets`), interactive field mapping to tidyverse code (`mutate`, `left_join`, `case_match`), discrepancy recoding, and local Ollama / OpenAI LLM integration with direct RStudio script and console injection via `rstudioapi`.

**Architecture:** A Dual-Hybrid R package pairing an RStudio Addin / Shiny Gadget (for live bi-directional R reactivity, `rstudioapi` injection, and LLM bridges) with an exportable `htmlwidget` (for self-contained static HTML reports). Frontend is an infinite pan-and-wheel-zoom 2D canvas with draggable virtualized table cards, SVG connector splines, cell color palettes, and discrepancy inspectors. Backend consists of S3 normalizers, AST/string tidyverse code generators, and `httr2` LLM connectors.

**Tech Stack:** R 4.5+, `shiny`, `htmltools`, `htmlwidgets`, `dplyr`, `rstudioapi`, `httr2`, `testthat`, vanilla JS, CSS3 Flexbox/Grid, and Panzoom.

---

### Task 1: Package Scaffolding & S3 Universal Normalization Engine (`sv_normalize`)

**Files:**
- Create: `DESCRIPTION`
- Create: `NAMESPACE`
- Create: `R/normalize.R`
- Create: `tests/testthat.R`
- Create: `tests/testthat/test-normalize.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-normalize.R` verifying that `sv_normalize()` handles:
1. `data.frame` and `tibble` (extracts rows, columns, types, and raw json-ready data)
2. `base::table` (converts to frequency data frame)
3. `gt::gt` objects (renders HTML via `gt::as_raw_html()` and retains `$data`)
4. `flextable::flextable` objects (renders HTML and retains underlying dataset)
5. `htmlwidgets` objects (wraps widget container)

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-normalize.R')"`
Expected: FAIL (function `sv_normalize` not found)

**Step 3: Implement minimal code**
Create `DESCRIPTION`, `NAMESPACE`, and `R/normalize.R` defining:
- `sv_normalize(x, name = NULL, ...)` S3 generic
- Methods: `sv_normalize.data.frame`, `sv_normalize.table`, `sv_normalize.gt_tbl`, `sv_normalize.flextable`, `sv_normalize.htmlwidget`, `sv_normalize.default`
- Returns an S3 object of class `sideview_card` with fields: `id`, `name`, `type` (`"grid"` | `"html"` | `"widget"`), `data`, `html_content`, `dims`, `col_types`.

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-normalize.R')"`
Expected: PASS with 0 failures

**Step 5: Commit**
```bash
git add DESCRIPTION NAMESPACE R/normalize.R tests/
git commit -m "feat(core): add package scaffolding and universal table normalizer"
```

---

### Task 2: Tidyverse Code Generation Engine (`sv_codegen`)

**Files:**
- Create: `R/codegen.R`
- Create: `tests/testthat/test-codegen.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-codegen.R` testing:
1. `sv_code_rename(df_name, old_col, new_col)` -> produces `df %>% dplyr::rename(new_col = old_col)`
2. `sv_code_join(df1, df2, col1, col2, type)` -> produces `df1 %>% dplyr::left_join(df2, by = c("col1" = "col2"))`
3. `sv_code_mutate(df_name, new_col, expr)` -> produces `df %>% dplyr::mutate(new_col = expr)`
4. `sv_detect_discrepancies(x, y)` -> returns list with `exact_matches`, `fuzzy_matches` (Levenshtein distance <= 2), `only_in_x`, `only_in_y`
5. `sv_code_recode(df_name, col, mapping)` -> produces `df %>% dplyr::mutate(col = dplyr::case_match(col, ...))`

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-codegen.R')"`
Expected: FAIL (functions not defined)

**Step 3: Implement minimal code**
Create `R/codegen.R` implementing all generator functions, string escaping, formatting, and fuzzy discrepancy matching using base R string distances.

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-codegen.R')"`
Expected: PASS

**Step 5: Commit**
```bash
git add R/codegen.R tests/testthat/test-codegen.R
git commit -m "feat(codegen): add tidyverse pipeline generation and discrepancy recoder"
```

---

### Task 3: Local Ollama & OpenAI-Compatible LLM Engine (`sv_llm`)

**Files:**
- Create: `R/llm.R`
- Create: `tests/testthat/test-llm.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-llm.R` testing:
1. `sv_build_schema_context(cards)` produces privacy-safe schema summaries (column names, types, value ranges/factors, row counts) without leaking private raw records.
2. `sv_build_prompt(user_prompt, schema_context)` formats system message instructing the LLM to output pure executable tidyverse R code.
3. `sv_extract_code(response_text)` parses code fence blocks (` ```r ... ``` `) out of conversational text.
4. `sv_call_llm()` constructs valid HTTP requests via `httr2` for Ollama and OpenAI format.

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-llm.R')"`
Expected: FAIL

**Step 3: Implement minimal code**
Implement `R/llm.R` with schema extraction, prompt builder, markdown code extractor, and `httr2` request executors supporting both `http://localhost:11434` and standard OpenAI endpoints.

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-llm.R')"`
Expected: PASS

**Step 5: Commit**
```bash
git add R/llm.R tests/testthat/test-llm.R
git commit -m "feat(llm): add privacy-safe schema context and dual Ollama/OpenAI bridge"
```

---

### Task 4: RStudio Script & Console Injection Service (`sv_rstudio`)

**Files:**
- Create: `R/rstudio.R`
- Create: `tests/testthat/test-rstudio.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-rstudio.R` testing:
1. `sv_insert_code(code)`: calls `rstudioapi::insertText` if RStudio is running; falls back to returning the formatted code if in headless/testing mode.
2. `sv_send_to_console(code, execute = TRUE)`: calls `rstudioapi::sendToConsole` if available.
3. `sv_is_rstudio_available()`: cleanly checks availability without error.

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-rstudio.R')"`
Expected: FAIL

**Step 3: Implement minimal code**
Implement `R/rstudio.R` with robust error guards and headless fallback.

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-rstudio.R')"`
Expected: PASS

**Step 5: Commit**
```bash
git add R/rstudio.R tests/testthat/test-rstudio.R
git commit -m "feat(rstudio): add rstudioapi script injection and console execution bridges"
```

---

### Task 5: 2D Infinite Canvas, Draggable Cards & Web UI Assets (`inst/www/`)

**Files:**
- Create: `inst/www/panzoom.min.js`
- Create: `inst/www/sideview.css`
- Create: `inst/www/sideview.js`
- Create: `tests/testthat/test-assets.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-assets.R` checking that all web assets exist, are valid non-empty files, and expose required DOM initialization routines.

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-assets.R')"`
Expected: FAIL

**Step 3: Implement minimal code**
1. Add lightweight, zero-dependency Panzoom engine for wheel zoom and canvas pan.
2. Build `inst/www/sideview.css`: infinite canvas grid background, draggable card frames, header badges, color highlighter swatches, SVG connector overlay, action drawer, AI bottom bar.
3. Build `inst/www/sideview.js`:
   * Panzoom initialization on canvas container with wheel zoom centered at cursor.
   * Drag-and-drop table cards with position tracking and snap-to-edge docking.
   * Virtualized scrollable table rendering with cell color picker.
   * Field click-to-connect SVG line drawing between columns.
   * Synchronized vertical scroll handler for linked table pairs.
   * Shiny message passing (`Shiny.setInputValue`).

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-assets.R')"`
Expected: PASS

**Step 5: Commit**
```bash
git add inst/www/ tests/testthat/test-assets.R
git commit -m "feat(ui): add 2D infinite canvas, panzoom, draggable cards, and SVG connectors"
```

---

### Task 6: Shiny Gadget Application & RStudio Addin (`sv_app` / `sideview`)

**Files:**
- Create: `R/app_ui.R`
- Create: `R/app_server.R`
- Create: `R/sideview.R`
- Create: `inst/rstudio/addins.dcf`
- Create: `tests/testthat/test-app.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-app.R` testing:
1. `sideview_ui()` builds a valid HTML tag list containing the canvas, toolbar, floating AI bar, and asset dependencies.
2. `sideview_server()` correctly registers handlers for:
   * `column_mapped` -> calls `sv_code_join` / `sv_code_mutate`
   * `discrepancy_check` -> calls `sv_detect_discrepancies`
   * `column_renamed` -> generates `dplyr::rename`
   * `run_ai_prompt` -> calls `sv_call_llm`
   * `inject_script` -> calls `sv_insert_code`
   * `send_console` -> calls `sv_send_to_console`
3. Entry point `sideview(...)` accepts heterogeneous tables and launches the gadget viewer.

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-app.R')"`
Expected: FAIL

**Step 3: Implement minimal code**
Implement `R/app_ui.R`, `R/app_server.R`, `R/sideview.R`, and `inst/rstudio/addins.dcf`.

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-app.R')"`
Expected: PASS

**Step 5: Commit**
```bash
git add R/app_ui.R R/app_server.R R/sideview.R inst/rstudio/addins.dcf tests/testthat/test-app.R
git commit -m "feat(addin): add Shiny Gadget application, server reactivity, and RStudio addin registration"
```

---

### Task 7: Exportable Standalone HTML Widget (`save_sideview`)

**Files:**
- Create: `R/widget.R`
- Create: `inst/htmlwidgets/sideview.yaml`
- Create: `tests/testthat/test-widget.R`

**Step 1: Write the failing test**
Create `tests/testthat/test-widget.R` testing:
1. `sideview_widget(cards)` creates an object of class `htmlwidget`.
2. `save_sideview(widget, file)` renders a standalone self-contained HTML file to disk.

**Step 2: Run test to verify it fails**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-widget.R')"`
Expected: FAIL

**Step 3: Implement minimal code**
Implement `R/widget.R`, `inst/htmlwidgets/sideview.yaml`, and `save_sideview()`.

**Step 4: Run test to verify it passes**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-widget.R')"`
Expected: PASS

**Step 5: Commit**
```bash
git add R/widget.R inst/htmlwidgets/ tests/testthat/test-widget.R
git commit -m "feat(export): add standalone htmlwidget export and save_sideview"
```

---

### Task 8: End-to-End Integration Test & Package Documentation

**Files:**
- Create: `tests/testthat/test-e2e.R`
- Create: `README.md`
- Create: `man/` documentation files

**Step 1: Write end-to-end integration test**
Simulate a complete workflow with 3 tables (a `tibble`, a `data.frame`, and a `gt` table):
- Normalize tables
- Generate column rename and join code
- Detect value discrepancies
- Synthesize an AI prompt schema context
- Verify `htmlwidget` export produces a readable HTML document.

**Step 2: Run all tests**
Run: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"`
Expected: All tests PASS with 0 errors and 0 warnings.

**Step 3: Add README.md & R documentation**
Write comprehensive package docs with usage examples, screenshots/diagrams, and Ollama setup guides.

**Step 4: Commit**
```bash
git add tests/testthat/test-e2e.R README.md man/
git commit -m "docs: add comprehensive README, vignettes, and end-to-end integration test suite"
```
