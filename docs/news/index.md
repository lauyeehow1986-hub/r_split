# Changelog

## sideview 0.2.0

#### Pillar 1: Big Data Scalability & CRAN Readiness

- **DOM Virtualization Engine**: Added `VirtualTable` in `sideview.js`
  and `sideview.css`, bounding active table DOM nodes to ~30 rows with
  dynamic spacer elements and supporting 100k+ rows at 60 FPS scrolling.
- **Arrow & DuckDB Lazy Ingestion**: Added zero-copy schema extraction
  methods (`sv_normalize.arrow_table()`, `sv_normalize.Dataset()`,
  `sv_normalize.tbl_duckdb_connection()`) with soft-dependency guards in
  `Suggests:`.
- **Multi-Key Composite Joins**: Enhanced
  [`sv_code_join()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_code_join.md)
  and server reactivity to support vector keys
  (`by = c("key1" = "key1", "key2" = "key2")`) and relational
  multi-table pipeline chaining.

#### Pillar 2: Advanced Visual Wrangling & Profiling

- **Visual Pivoting Codegen**: Added
  [`sv_code_pivot_longer()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_code_pivot_longer.md)
  and
  [`sv_code_pivot_wider()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_code_pivot_wider.md)
  with full syntactic backtick escaping and custom `values_fn`
  aggregation.
- **Group & Summarize Builder**: Added
  [`sv_code_group_summarize()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_code_group_summarize.md)
  generating reproducible
  `dplyr::group_by(...) %>% dplyr::summarise(..., .groups = 'drop')`
  workflows.
- **Header Column Profiling**: Embedded inline SVG 5-bin distribution
  sparklines (`<svg class="sideview-sparkline">`), categorical frequency
  distribution bars (`.sideview-cat-profile`), and color-coded
  missingness badges (`.sideview-na-badge`) with 25k-sample performance
  optimization.

#### Pillar 3: Canvas State Persistence & Cloud Sharing

- **State Serialization APIs**: Added
  [`new_sideview_state()`](https://lauyeehow1986-hub.github.io/sideview/reference/new_sideview_state.md),
  [`sv_save_state()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_save_state.md),
  and
  [`sv_load_state()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_load_state.md)
  supporting both portable `.json` and native R `.rds` workspace
  serialization for canvas pan/zoom, card coordinates, splines, and
  pipelines.

#### Pillar 4: Intelligent Copilot & Auto-Mapping

- **Heuristic Foreign Key Detection**: Added
  [`sv_suggest_mappings()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_suggest_mappings.md)
  computing 3-part composite scores (name similarity with ID suffix
  detection, type compatibility, and Jaccard overlap) with precomputed
  unique sets and logical column exclusion.
- **Suggested Splines & Discrepancy Auto-Clean**: Added animated dashed
  suggested splines (`.sideview-spline-suggested dashMove`) with
  click-to-accept join mapping, and
  [`sv_auto_clean_rules()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_auto_clean_rules.md)
  /
  [`sv_code_auto_clean()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_auto_clean_rules.md)
  for automatic
  [`dplyr::case_match()`](https://dplyr.tidyverse.org/reference/case_match.html)
  crosswalk synthesis.
- **Conversational AI Copilot Drawer**: Added multi-turn chat tab with
  context retention
  ([`sv_build_chat_prompt()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_build_chat_prompt.md)),
  turn-based history sliding window (20 turns), and active pipeline code
  guards.

#### Pillar 5: Automated Computer Use & GUI Verification

- **Automated GUI Test Suite**: Added
  `tests/testthat/test-computer-use-gui.R` and headless DOM test runner
  `gui-test-runner.js` verifying 6 core interaction scenarios (canvas
  coordinates, dragging, port click / spline connect, suggested spline
  acceptance, sorting/filtering, drawer action dispatch) with diagnostic
  dumps in [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

## sideview 0.1.0

### Recent Features & Enhancements

#### Interactive Canvas & Navigation

- **Dual Synchronized Scrolling**: The sync scroll feature (`[🔗]` link
  icon in card headers) now synchronously locks both vertical rows
  (`scrollTop`) and horizontal columns (`scrollLeft`) in proportional
  lockstep across wide datasets.
- **Interactive Column Spline Disconnection**:
  - Hovering over any connection spline displays a red highlight glow.
  - Direct click or right-click on any spline or connection port
    immediately removes the connection.
  - Shiny reactivity now dispatches `column_disconnected` to dynamically
    update code generation and downstream operations.
- **Port State Reset & Clearing**: Enhanced `clearOperations()` to
  reliably purge active connecting port states (`this.activePort`) and
  strip visual `.connecting` classes when resetting the canvas.
- **Table Card Snapping & Dragging**: Improved magnetic guideline
  alignment when dragging cards near each other.
- **Syntax Validation Suite**: Added automated Node.js syntax parsing in
  `tests/testthat/test-assets.R` to ensure zero runtime script syntax
  errors.

#### Data Manipulation & Code Generation

- **Interactive Column Sorting**:
  - Tri-state toggle on column header sort indicators (`▲` Ascending,
    `▼` Descending, `original`).
  - Live in-memory row reordering across table cards.
  - Synthesizes and previews corresponding
    [`dplyr::arrange()`](https://dplyr.tidyverse.org/reference/arrange.html)
    pipelines in the Action Drawer.
- **Interactive Column Filtering**:
  - Floating popover activated by column filter icon (`🔍`).
  - Supports numeric comparisons (`>`, `>=`, `<`, `<=`), exact matches
    (`==`, `!=`), and text substring filters (`contains`).
  - Filters rows in real time and synthesizes
    [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
    pipelines.
- **Non-Syntactic Identifier Escaping**: Added client-side
  `escapeColIdentifier()` in `sideview.js` so column names with spaces
  or symbols (e.g. `Patient ID`, `Glucose (mg/dL)`) are safely wrapped
  in backticks across filter and arrange pipelines.
- **List-Column & Vector Safeguard**: Hardened HTML grid table rendering
  in
  [`sideview_ui()`](https://lauyeehow1986-hub.github.io/sideview/reference/sideview_ui.md)
  to handle nested list-columns and vectors safely with a `[list]`
  placeholder, avoiding length \> 1 evaluation errors under R 4.2+.

#### Action Drawer & Workflow Controls

- **Four Execution Modes**:
  1.  `Insert Script`: Pastes code at the current cursor location in the
      active RStudio script document via
      [`rstudioapi::insertText()`](https://rstudio.github.io/rstudioapi/reference/rstudio-documents.html).
  2.  `Run & Exit`: Sends code to the R console and closes the gadget
      immediately.
  3.  `Run in R`: Evaluates code directly inside the current R
      environment (`.GlobalEnv`) with live row/column toast feedback.
  4.  `Run Console`: Previews and buffers code for the RStudio console.
- **Clearing Controls**:
  - Added a dedicated `Clear` button in the Action Drawer to reset all
    active splines, sort orders, and filters.
  - Added an `[✓] Auto-clear` toggle to automatically reset canvas
    interactions upon code insertion or copy.

#### LLM Assistance & Privacy Context

- **Local Ollama Integration**: Full support for local models such as
  `gemma4:26b` and `llama3.2` with zero data leakage
  (`http://localhost:11434`).
- **Cloud OpenAI-Compatible Support**: Connect to OpenAI, OpenRouter,
  Groq, LM Studio, or vLLM.
- **Privacy-Safe Schema Synthesis**: Prompts contain table names, column
  types, and high-level distribution ranges without exposing
  confidential raw records.

#### Testing & Verification

- **705 Automated Tests**: Full test suite across 9 contexts with 100%
  pass rate covering universal normalization, codegen, LLM prompts,
  RStudio bridges, reactive gadget events, HTML widgets, and static
  asset syntax.

------------------------------------------------------------------------

## sideview 0.1.0

- Initial release of **`sideview`**: Multi-Table 2D Infinite Canvas for
  interactive data exploration, visual field mapping, and LLM-assisted
  Tidyverse code generation.
- Universal S3 normalization engine
  ([`sv_normalize()`](https://lauyeehow1986-hub.github.io/sideview/reference/sv_normalize.md))
  supporting `data.frame`, `tibble`,
  [`base::table`](https://rdrr.io/r/base/table.html), `matrix`, `gt`,
  `flextable`, and `htmlwidgets`.
- Standalone self-contained HTML widget export via
  [`save_sideview()`](https://lauyeehow1986-hub.github.io/sideview/reference/save_sideview.md).
- Interactive Shiny Gadget and RStudio Addin
  ([`sideview()`](https://lauyeehow1986-hub.github.io/sideview/reference/sideview.md),
  [`sideview_addin()`](https://lauyeehow1986-hub.github.io/sideview/reference/sideview_addin.md)).
