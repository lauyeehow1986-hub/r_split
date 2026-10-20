# sideview (development version)

## Recent Features & Enhancements

### Interactive Canvas & Navigation
* **Dual Synchronized Scrolling**: The sync scroll feature (`[🔗]` link icon in card headers) now synchronously locks both vertical rows (`scrollTop`) and horizontal columns (`scrollLeft`) in proportional lockstep across wide datasets.
* **Interactive Column Spline Disconnection**:
  * Hovering over any connection spline displays a red highlight glow.
  * Direct click or right-click on any spline or connection port immediately removes the connection.
  * Shiny reactivity now dispatches `column_disconnected` to dynamically update code generation and downstream operations.
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
* **Tidyverse Code Generation Engine**:
  * Extended code generators with `sv_code_arrange()` and `sv_code_filter()`.
  * Improved non-syntactic column name escaping via `sv_escape_ident()`.

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

---

# sideview 0.1.0

* Initial release of **`sideview`**: Multi-Table 2D Infinite Canvas for interactive data exploration, visual field mapping, and LLM-assisted Tidyverse code generation.
* Universal S3 normalization engine (`sv_normalize()`) supporting `data.frame`, `tibble`, `base::table`, `matrix`, `gt`, `flextable`, and `htmlwidgets`.
* Standalone self-contained HTML widget export via `save_sideview()`.
* Interactive Shiny Gadget and RStudio Addin (`sideview()`, `sideview_addin()`).
