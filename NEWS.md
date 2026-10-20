# sideview (development version)

## Recent Features & Enhancements

### Interactive Canvas & Navigation
* **Dual Synchronized Scrolling**: The sync scroll feature (`[🔗]` link icon in card headers) now synchronously locks both vertical rows (`scrollTop`) and horizontal columns (`scrollLeft`) in proportional lockstep across wide datasets.
* **Interactive Column Spline Disconnection**:
  * Hovering over any connection spline displays a red highlight glow.
  * Direct click or right-click on any spline or connection port immediately removes the connection.
  * Shiny reactivity now dispatches `column_disconnected` to dynamically update code generation and downstream operations.
* **Port State Reset & Clearing**: Enhanced `clearOperations()` to reliably purge active connecting port states (`this.activePort`) and strip visual `.connecting` classes when resetting the canvas.
* **Table Card Snapping & Dragging**: Improved magnetic guideline alignment when dragging cards near each other.
* **Syntax Validation Suite**: Added automated Node.js syntax parsing in `tests/testthat/test-assets.R` to ensure zero runtime script syntax errors.

### Data Manipulation & Code Generation
* **Interactive Column Sorting**:
  * Tri-state toggle on column header sort indicators (`▲` Ascending, `▼` Descending, `original`).
  * Live in-memory row reordering across table cards.
  * Synthesizes and previews corresponding `dplyr::arrange()` pipelines in the Action Drawer.
* **Interactive Column Filtering**:
  * Floating popover activated by column filter icon (`🔍`).
  * Supports numeric comparisons (`>`, `>=`, `<`, `<=`), exact matches (`==`, `!=`), and text substring filters (`contains`).
  * Filters rows in real time and synthesizes `dplyr::filter()` pipelines.
* **Non-Syntactic Identifier Escaping**: Added client-side `escapeColIdentifier()` in `sideview.js` so column names with spaces or symbols (e.g. `Patient ID`, `Glucose (mg/dL)`) are safely wrapped in backticks across filter and arrange pipelines.
* **List-Column & Vector Safeguard**: Hardened HTML grid table rendering in `sideview_ui()` to handle nested list-columns and vectors safely with a `[list]` placeholder, avoiding length > 1 evaluation errors under R 4.2+.

### Action Drawer & Workflow Controls
* **Four Execution Modes**:
  1. `Insert Script`: Pastes code at the current cursor location in the active RStudio script document via `rstudioapi::insertText()`.
  2. `Run & Exit`: Sends code to the R console and closes the gadget immediately.
  3. `Run in R`: Evaluates code directly inside the current R environment (`.GlobalEnv`) with live row/column toast feedback.
  4. `Run Console`: Previews and buffers code for the RStudio console.
* **Clearing Controls**:
  * Added a dedicated `Clear` button in the Action Drawer to reset all active splines, sort orders, and filters.
  * Added an `[✓] Auto-clear` toggle to automatically reset canvas interactions upon code insertion or copy.

### LLM Assistance & Privacy Context
* **Local Ollama Integration**: Full support for local models such as `gemma4:26b` and `llama3.2` with zero data leakage (`http://localhost:11434`).
* **Cloud OpenAI-Compatible Support**: Connect to OpenAI, OpenRouter, Groq, LM Studio, or vLLM.
* **Privacy-Safe Schema Synthesis**: Prompts contain table names, column types, and high-level distribution ranges without exposing confidential raw records.

### Testing & Verification
* **705 Automated Tests**: Full test suite across 9 contexts with 100% pass rate covering universal normalization, codegen, LLM prompts, RStudio bridges, reactive gadget events, HTML widgets, and static asset syntax.

---

# sideview 0.1.0

* Initial release of **`sideview`**: Multi-Table 2D Infinite Canvas for interactive data exploration, visual field mapping, and LLM-assisted Tidyverse code generation.
* Universal S3 normalization engine (`sv_normalize()`) supporting `data.frame`, `tibble`, `base::table`, `matrix`, `gt`, `flextable`, and `htmlwidgets`.
* Standalone self-contained HTML widget export via `save_sideview()`.
* Interactive Shiny Gadget and RStudio Addin (`sideview()`, `sideview_addin()`).
