#' Escape R Identifiers with Backticks If Non-Syntactic
#'
#' @param x Character vector of identifier names.
#' @return Character vector of identifiers, escaped with backticks if necessary.
#' @export
sv_escape_ident <- function(x) {
  if (is.null(x) || length(x) == 0) return(character(0))
  vapply(x, function(name) {
    if (is.na(name)) return(NA_character_)
    if (grepl("^`[^`]+`$", name)) return(name)
    reserved <- c("if", "else", "repeat", "while", "function", "for", "in", 
                  "next", "break", "TRUE", "FALSE", "NULL", "Inf", "NaN", 
                  "NA", "NA_integer_", "NA_real_", "NA_complex_", "NA_character_")
    is_syntactic <- (make.names(name) == name) && !(name %in% reserved)
    if (is_syntactic) {
      name
    } else {
      escaped <- gsub("`", "\\\\`", name)
      sprintf("`%s`", escaped)
    }
  }, FUN.VALUE = character(1), USE.NAMES = FALSE)
}

#' Generate tidyverse Code for Column Renaming
#'
#' @param df_name Name of the data frame.
#' @param old_col Existing column name(s).
#' @param new_col New column name(s).
#' @param pipe Logical; if TRUE, uses pipe syntax `df %>% dplyr::rename(...)`.
#' @return A character string of R code.
#' @export
sv_code_rename <- function(df_name, old_col, new_col, pipe = FALSE) {
  if (length(old_col) == 0 || length(new_col) == 0) {
    stop("`old_col` and `new_col` must not be empty.")
  }
  if (length(old_col) != length(new_col)) {
    stop("`old_col` and `new_col` must have the same length.")
  }
  esc_old <- sv_escape_ident(old_col)
  esc_new <- sv_escape_ident(new_col)
  args <- paste(sprintf("%s = %s", esc_new, esc_old), collapse = ", ")
  
  if (pipe) {
    esc_df <- sv_escape_ident(df_name)
    sprintf("%s %%>%% dplyr::rename(%s)", esc_df, args)
  } else {
    esc_df <- if (is.null(df_name) || !nzchar(df_name)) NULL else sv_escape_ident(df_name)
    if (is.null(esc_df)) {
      sprintf("dplyr::rename(%s)", args)
    } else {
      sprintf("dplyr::rename(%s, %s)", esc_df, args)
    }
  }
}

#' Generate tidyverse Code for Relational Table Joins
#'
#' @param df1 Name of the first data frame.
#' @param df2 Name of the second data frame.
#' @param col1 Key column name(s) in df1.
#' @param col2 Key column name(s) in df2 (defaults to col1).
#' @param join_type Type of join: "left", "inner", "anti", "right", "full", "semi".
#' @param pipe Logical; if TRUE, uses pipe syntax `df1 %>% dplyr::<join_type>(df2, ...)`.
#' @return A character string of R code.
#' @export
sv_code_join <- function(df1, df2, col1, col2 = col1, join_type = "left", pipe = FALSE) {
  jt <- tolower(join_type)
  jt <- sub("_join$", "", jt)
  valid_joins <- c("left", "inner", "anti", "right", "full", "semi")
  if (!jt %in% valid_joins) {
    stop(sprintf("Unsupported join_type: '%s'. Must be one of: %s", join_type, paste(valid_joins, collapse = ", ")))
  }
  fn_name <- paste0("dplyr::", jt, "_join")
  
  if (length(col1) == 0 || length(col2) == 0) {
    stop("Join columns (`col1` and `col2`) must not be empty.")
  }
  if (length(col1) != length(col2)) {
    stop("`col1` and `col2` must have the same length.")
  }
  
  # Format by argument
  is_same <- identical(col1, col2) || (!anyNA(col1) && !anyNA(col2) && all(col1 == col2))
  if (is_same) {
    if (length(col1) == 1) {
      by_str <- sprintf('by = %s', deparse1(col1))
    } else {
      by_str <- sprintf('by = c(%s)', paste(vapply(col1, deparse1, character(1)), collapse = ", "))
    }
  } else {
    pairs <- sprintf('%s = %s', vapply(col1, deparse1, character(1)), vapply(col2, deparse1, character(1)))
    by_str <- sprintf('by = c(%s)', paste(pairs, collapse = ", "))
  }
  
  esc_df1 <- sv_escape_ident(df1)
  esc_df2 <- sv_escape_ident(df2)
  
  if (pipe) {
    sprintf("%s %%>%% %s(%s, %s)", esc_df1, fn_name, esc_df2, by_str)
  } else {
    sprintf("%s(%s, %s, %s)", fn_name, esc_df1, esc_df2, by_str)
  }
}

#' Generate tidyverse Code for Column Mutation
#'
#' @param df_name Name of the data frame.
#' @param new_col Name of the column(s) being created or transformed.
#' @param expr R expression string(s) to evaluate.
#' @param pipe Logical; if TRUE, uses pipe syntax `df %>% dplyr::mutate(...)`.
#' @return A character string of R code.
#' @export
sv_code_mutate <- function(df_name, new_col, expr, pipe = FALSE) {
  if (length(new_col) != length(expr)) {
    stop("`new_col` and `expr` must have the same length.")
  }
  esc_cols <- sv_escape_ident(new_col)
  args <- paste(sprintf("%s = %s", esc_cols, expr), collapse = ", ")
  
  if (pipe) {
    esc_df <- sv_escape_ident(df_name)
    sprintf("%s %%>%% dplyr::mutate(%s)", esc_df, args)
  } else {
    esc_df <- if (is.null(df_name) || !nzchar(df_name)) NULL else sv_escape_ident(df_name)
    if (is.null(esc_df)) {
      sprintf("dplyr::mutate(%s)", args)
    } else {
      sprintf("dplyr::mutate(%s, %s)", esc_df, args)
    }
  }
}

#' Generate tidyverse Code for Filtering Rows
#'
#' @param df_name Name of the data frame.
#' @param condition Character vector of boolean filter expressions.
#' @param pipe Logical; if TRUE, uses pipe syntax `df %>% dplyr::filter(...)`.
#' @return A character string of R code.
#' @export
sv_code_filter <- function(df_name, condition, pipe = FALSE) {
  args <- paste(condition, collapse = ", ")
  if (pipe) {
    esc_df <- sv_escape_ident(df_name)
    sprintf("%s %%>%% dplyr::filter(%s)", esc_df, args)
  } else {
    esc_df <- if (is.null(df_name) || !nzchar(df_name)) NULL else sv_escape_ident(df_name)
    if (is.null(esc_df)) {
      sprintf("dplyr::filter(%s)", args)
    } else {
      sprintf("dplyr::filter(%s, %s)", esc_df, args)
    }
  }
}

#' Generate tidyverse Code for Arranging (Sorting) Rows
#'
#' @param df_name Name of the data frame.
#' @param col Character vector of column name(s) to sort by.
#' @param desc Logical vector indicating descending order for each column.
#'   Recycled to match the length of `col`. Defaults to `FALSE`.
#' @param pipe Logical; if TRUE, uses pipe syntax `df %>% dplyr::arrange(...)`.
#' @return A character string of R code.
#' @export
sv_code_arrange <- function(df_name, col, desc = FALSE, pipe = FALSE) {
  if (is.null(col) || length(col) == 0) {
    stop('`col` must not be empty.')
  }
  esc_cols <- sv_escape_ident(col)
  desc <- rep_len(as.logical(desc), length(col))
  
  col_terms <- mapply(function(c_name, is_desc) {
    if (isTRUE(is_desc)) {
      sprintf('dplyr::desc(%s)', c_name)
    } else {
      c_name
    }
  }, esc_cols, desc, USE.NAMES = FALSE)
  
  args <- paste(col_terms, collapse = ', ')
  
  if (pipe) {
    esc_df <- sv_escape_ident(df_name)
    sprintf("%s %%>%% dplyr::arrange(%s)", esc_df, args)
  } else {
    esc_df <- if (is.null(df_name) || !nzchar(df_name)) NULL else sv_escape_ident(df_name)
    if (is.null(esc_df)) {
      sprintf('dplyr::arrange(%s)', args)
    } else {
      sprintf('dplyr::arrange(%s, %s)', esc_df, args)
    }
  }
}

#' Generate tidyverse Code for Selecting Columns
#'
#' @param df_name Name of the data frame.
#' @param cols Character vector of column names to select.
#' @param pipe Logical; if TRUE, uses pipe syntax `df %>% dplyr::select(...)`.
#' @return A character string of R code.
#' @export
sv_code_select <- function(df_name, cols, pipe = FALSE) {
  esc_cols <- sv_escape_ident(cols)
  args <- paste(esc_cols, collapse = ", ")
  if (pipe) {
    esc_df <- sv_escape_ident(df_name)
    sprintf("%s %%>%% dplyr::select(%s)", esc_df, args)
  } else {
    esc_df <- if (is.null(df_name) || !nzchar(df_name)) NULL else sv_escape_ident(df_name)
    if (is.null(esc_df)) {
      sprintf("dplyr::select(%s)", args)
    } else {
      sprintf("dplyr::select(%s, %s)", esc_df, args)
    }
  }
}

#' Detect Exact Matches, Discrepancies, and Fuzzy Near-Matches
#'
#' Compares distinct values between two vectors (e.g. columns mapped across tables),
#' computing exact matches, values only in x, values only in y, fuzzy/near-matches
#' using Levenshtein distance (adist), and comprehensive match statistics.
#'
#' @param x Vector of values from the first column.
#' @param y Vector of values from the second column.
#' @param max_distance Maximum Levenshtein edit distance for fuzzy matching (default 2).
#' @return A list with elements:
#' \itemize{
#'   \item `exact_matches`: character vector of values present in both x and y.
#'   \item `fuzzy_matches`: data.frame with columns `x`, `y`, `distance`.
#'   \item `only_in_x`: character vector of values present only in x.
#'   \item `only_in_y`: character vector of values present only in y.
#'   \item `stats`: list of match statistics (counts, NA counts, match rate).
#'   \item `match_stats`: alias to `stats`.
#' }
#' @export
sv_detect_discrepancies <- function(x, y, max_distance = 2) {
  max_dist <- if (is.null(max_distance) || length(max_distance) == 0 || is.na(max_distance[1])) {
    2L
  } else {
    max(0L, as.integer(max_distance[1]))
  }
  
  na_x <- sum(is.na(x))
  na_y <- sum(is.na(y))
  
  clean_x <- if (is.null(x)) character(0) else as.character(x[!is.na(x)])
  clean_y <- if (is.null(y)) character(0) else as.character(y[!is.na(y)])
  
  ux <- unique(clean_x)
  uy <- unique(clean_y)
  
  exact_matches <- intersect(ux, uy)
  only_in_x <- setdiff(ux, uy)
  only_in_y <- setdiff(uy, ux)
  
  # Vectorized fuzzy matching: calculate distance matrix in C
  fuzzy_matches <- data.frame(
    x = character(0),
    y = character(0),
    distance = integer(0),
    stringsAsFactors = FALSE
  )
  
  if (length(only_in_x) > 0 && length(uy) > 0 && max_dist > 0) {
    dist_mat <- utils::adist(only_in_x, uy)
    m_idx <- which(dist_mat <= max_dist, arr.ind = TRUE)
    if (nrow(m_idx) > 0) {
      fuzzy_matches <- data.frame(
        x = as.character(only_in_x[m_idx[, 1]]),
        y = as.character(uy[m_idx[, 2]]),
        distance = as.integer(dist_mat[m_idx]),
        stringsAsFactors = FALSE
      )
      fuzzy_matches <- unique(fuzzy_matches)
      fuzzy_matches <- fuzzy_matches[order(fuzzy_matches$distance, fuzzy_matches$x, fuzzy_matches$y), , drop = FALSE]
      rownames(fuzzy_matches) <- NULL
    }
  }
  
  total_x <- length(x)
  total_y <- length(y)
  unique_x <- length(ux)
  unique_y <- length(uy)
  exact_count <- length(exact_matches)
  fuzzy_count <- nrow(fuzzy_matches)
  only_x_count <- length(only_in_x)
  only_y_count <- length(only_in_y)
  match_rate <- if (unique_x > 0) exact_count / unique_x else 0
  
  stats <- list(
    total_x = total_x,
    total_y = total_y,
    unique_x = unique_x,
    unique_y = unique_y,
    exact_count = exact_count,
    fuzzy_count = fuzzy_count,
    only_x_count = only_x_count,
    only_y_count = only_y_count,
    na_x = na_x,
    na_y = na_y,
    match_rate = match_rate
  )
  
  list(
    exact_matches = exact_matches,
    fuzzy_matches = fuzzy_matches,
    only_in_x = only_in_x,
    only_in_y = only_in_y,
    stats = stats,
    match_stats = stats
  )
}

#' Generate tidyverse Code for Categorical Recoding and Discrepancy Crosswalks
#'
#' @param df_name Name of the data frame.
#' @param col Column name to recode.
#' @param crosswalk Mapping between source and target values. Can be:
#'   \itemize{
#'     \item A data.frame with source values in column 1 and target values in column 2.
#'     \item A named character vector (names = source values, values = target values).
#'     \item A named list where names are target values and elements are vectors of source values.
#'   }
#' @param default Fallback value for unmatched records. If NULL, omitted.
#'   If equal to `col`, emits unquoted column name `.default = <col>`.
#' @param method Recoding function: "case_match" (dplyr) or "fct_recode" (forcats).
#' @param pipe Logical; if TRUE, uses pipe syntax `df %>% dplyr::mutate(...)`.
#' @return A character string of R code.
#' @export
sv_code_recode <- function(df_name, col, crosswalk, default = NULL, 
                           method = c("case_match", "fct_recode"), pipe = FALSE) {
  method <- match.arg(method)
  
  from_vals <- character(0)
  to_vals <- character(0)
  
  if (is.data.frame(crosswalk)) {
    if (ncol(crosswalk) < 2) {
      stop("`crosswalk` data frame must have at least 2 columns.")
    }
    if (all(c("from", "to") %in% names(crosswalk))) {
      from_vals <- as.character(crosswalk$from)
      to_vals <- as.character(crosswalk$to)
    } else if (all(c("old", "new") %in% names(crosswalk))) {
      from_vals <- as.character(crosswalk$old)
      to_vals <- as.character(crosswalk$new)
    } else if (all(c("x", "y") %in% names(crosswalk))) {
      from_vals <- as.character(crosswalk$x)
      to_vals <- as.character(crosswalk$y)
    } else {
      from_vals <- as.character(crosswalk[[1]])
      to_vals <- as.character(crosswalk[[2]])
    }
  } else if (is.list(crosswalk) && !is.null(names(crosswalk)) && !is.character(crosswalk)) {
    for (nm in names(crosswalk)) {
      srcs <- as.character(crosswalk[[nm]])
      from_vals <- c(from_vals, srcs)
      to_vals <- c(to_vals, rep(nm, length(srcs)))
    }
  } else if (is.character(crosswalk)) {
    if (is.null(names(crosswalk))) {
      stop("`crosswalk` vector must be named (e.g. c('old_val' = 'new_val')).")
    }
    from_vals <- names(crosswalk)
    to_vals <- unname(crosswalk)
  } else {
    stop("`crosswalk` must be a data frame, named list, or named character vector.")
  }
  
  esc_col <- sv_escape_ident(col)
  
  if (method == "case_match") {
    unique_targets <- unique(to_vals)
    case_lines <- character(0)
    for (tgt in unique_targets) {
      if (is.na(tgt)) {
        srcs <- from_vals[is.na(to_vals)]
        tgt_rep <- "NA"
      } else {
        srcs <- from_vals[!is.na(to_vals) & to_vals == tgt]
        tgt_rep <- deparse1(tgt)
      }
      
      format_src <- function(s) if (is.na(s)) "NA" else deparse1(s)
      if (length(srcs) == 1) {
        case_lines <- c(case_lines, sprintf("%s ~ %s", format_src(srcs), tgt_rep))
      } else {
        srcs_str <- paste(vapply(srcs, format_src, character(1)), collapse = ", ")
        case_lines <- c(case_lines, sprintf("c(%s) ~ %s", srcs_str, tgt_rep))
      }
    }
    
    if (!is.null(default)) {
      if (length(default) == 1 && is.na(default)) {
        case_lines <- c(case_lines, ".default = NA")
      } else if (identical(default, col) || identical(default, esc_col)) {
        case_lines <- c(case_lines, sprintf(".default = %s", esc_col))
      } else if (is.character(default)) {
        case_lines <- c(case_lines, sprintf(".default = %s", deparse1(default)))
      } else {
        case_lines <- c(case_lines, sprintf(".default = %s", as.character(default)))
      }
    }
    
    inner <- paste(c(esc_col, case_lines), collapse = ",\n    ")
    expr <- sprintf("dplyr::case_match(\n    %s\n  )", inner)
  } else {
    fct_lines <- sprintf("%s = %s", vapply(to_vals, deparse1, character(1)), vapply(from_vals, deparse1, character(1)))
    inner <- paste(c(esc_col, fct_lines), collapse = ",\n    ")
    expr <- sprintf("forcats::fct_recode(\n    %s\n  )", inner)
  }
  
  sv_code_mutate(df_name = df_name, new_col = col, expr = expr, pipe = pipe)
}
