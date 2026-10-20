# sideview: Multi-Table Infinite Canvas & Tidyverse Code Generation for R

**Date**: 2026-10-20  
**Status**: Validated Design Specification  
**Package Name**: `sideview`  

---

## 1. Executive Summary

`sideview` is an R package and RStudio addin designed to revolutionize how data analysts and researchers interact with multiple tables simultaneously. Unlike tabbed viewers (such as `dataviewR`) that force users to flip back and forth between datasets, `sideview` provides an infinite, hardware-accelerated 2D canvas where any number of tables can be placed side-by-side, zoomed via mouse wheel, panned, color-annotated, and visually linked.

Users can interactively click between columns across tables to generate idiomatic tidyverse code (`dplyr::mutate`, `dplyr::left_join`, `dplyr::case_match`, `forcats::fct_recode`), detect and resolve discrepancies, and invoke local (Ollama) or OpenAI-compatible LLMs to generate reproducible R pipelines that insert directly into the active RStudio script editor or R console via `rstudioapi`.

---

## 2. Architecture & Runtime Modes

`sideview` implements a **Dual-Hybrid Architecture**:

1. **Interactive RStudio Addin & Shiny Gadget (`sideview()`)**:
   * Runs in the RStudio Viewer pane or as a dedicated resizable gadget window.
   * Leverages bi-directional WebSocket reactivity between R and the web canvas.
   * Full access to `rstudioapi` for direct script cursor injection and console execution.
   * Orchestrates LLM requests and dynamic in-memory data pipeline updates.
2. **Exportable Standalone HTML Widget (`save_sideview()`)**:
   * Self-contained `htmlwidget` bundle with embedded datasets and layout states.
   * Renderable inside Quarto (`.qmd`), R Markdown (`.Rmd`), or shared as standalone `.html` files.

---

## 3. Universal Multi-Format Normalization Engine

`sideview` accepts arbitrary heterogeneous R tabular objects:
```r
sideview(tbl1, tbl2, my_gt, my_flex, my_widget, title = "Clinical Comparison")
```

The normalization pipeline dispatches across three major categories:

| Input Class | Display Strategy | Data Operations & Code-Gen Support |
| :--- | :--- | :--- |
| `data.frame`, `tibble`, `table`, `matrix` | Virtualized interactive grid (Tabulator/Canvas) | Full cell/column highlighting, renaming, filtering, mapping, mutation, recoding |
| `gt`, `gtsummary` | Rendered via `gt::as_raw_html()` with toggle to raw grid | Extracts underlying data frame (`gt_tbl$`_data`) for full tidyverse code generation |
| `flextable` | Rendered via `flextable::to_html()` with toggle to raw grid | Extracts underlying data frame (`flex$body$dataset`) for full tidyverse code generation |
| `htmlwidgets` (DT, reactable, etc.) | Sandboxed iframe / HTML dependency container | Visual side-by-side comparison alongside other datasets |

---

## 4. Canvas Viewport & Interactive Data Manipulation

### 4.1 Infinite 2D Panzoom Canvas
* **Mouse Wheel Zoom**: Smooth scaling centered on the cursor position (25% to 250% zoom).
* **Panning**: Middle-click or background drag to navigate large workspaces.
* **Minimap Navigation**: Collapsible overview canvas showing table coordinates with click-to-jump.
* **Snap-to-Edge Docking**: Dragging table headers allows free movement, with magnetic alignment for side-by-side row comparison.

### 4.2 Table Card Controls
* **Independent Scrolling**: Each table card maintains its own virtualized vertical and horizontal scrolling.
* **Synchronized Scroll Toggle**: A header link button locks vertical scroll positions between adjacent tables for synchronous row-by-row scanning.
* **Click-to-Rename**: Double-clicking a column header opens inline editing; logged to generate `dplyr::rename()`.
* **Interactive Filtering**: Column headers include filter dropdowns (text query, numeric range slider, categorical checklist).
* **Color Highlighter Palette**: Floating color swatch tool to highlight cells, rows, or entire columns.

---

## 5. Field Mapping, Discrepancies & Tidyverse Code Generation

### 5.1 Click-to-Connect Mapping
* Clicking a column in Table A and a column in Table B renders an interactive SVG connector spline.
* An **Action Drawer** provides three primary generators:
  1. **Relational Joins**: `left_join(x, y, by = c("col_a" = "col_b"))` with configurable join types (`left`, `inner`, `anti`, `full`).
  2. **Computed Mutations**: `mutate(new_col = expression)` with reference pills for source columns.
  3. **Categorical Crosswalk**: Pairing distinct values across columns.

### 5.2 Discrepancy Detection & Recode Engine
* Automated comparison of distinct values between mapped columns:
  * Identifies exact matches, fuzzy/near matches (Levenshtein distance, casing, whitespace), and unmatched values.
  * Drag-and-drop crosswalk matrix lets users align discrepancies.
  * Emits idiomatic tidyverse code:
    ```r
    df_cleaned <- df %>%
      mutate(status = case_match(
        status_raw,
        c("Compl.", "completed") ~ "Completed",
        "InProg" ~ "In Progress",
        .default = status_raw
      ))
    ```

---

## 6. Natural Language AI & RStudio Integration

### 6.1 Dual LLM Engine (Ollama & OpenAI Compatible)
* **Local Ollama Integration**: Connects to `http://localhost:11434` for zero-data-leakage local code generation.
* **OpenAI-Compatible Providers**: Connects to OpenAI, OpenRouter, Groq, LM Studio, or vLLM via API key and base URL.
* **Privacy-Safe Schema Context**: Prompts automatically include table schema metadata (column names, types, summary stats) without transmitting raw private patient/confidential records.

### 6.2 Code Insertion & Execution via `rstudioapi`
Every generated pipeline (whether from visual mapping or AI prompting) provides three one-click actions:
* **Insert into Active Script**: Uses `rstudioapi::insertText(code)` to paste code directly at the user's cursor.
* **Send to Console**: Uses `rstudioapi::sendToConsole(code, execute = TRUE)` to evaluate immediately.
* **Run & Refresh Canvas**: Evaluates the transformed pipeline in-memory and dynamically updates the canvas cards.
