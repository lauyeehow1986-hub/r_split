# Automated Package Install Permission Helper for testthat test suite
# If a suggested package is missing, prompts the user for permission to install
# when running interactively (or when SIDEVIEW_ASK_INSTALL="true") rather than
# silently skipping the test. In non-interactive batch/CI environments, it skips cleanly.

ensure_package_installed <- function(pkg, minimum_version = NULL, reason = NULL) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    if (!is.null(minimum_version) && utils::packageVersion(pkg) < minimum_version) {
      testthat::skip(sprintf("Package '%s' version is < %s", pkg, minimum_version))
    }
    return(invisible(TRUE))
  }

  can_prompt <- interactive() || identical(tolower(Sys.getenv("SIDEVIEW_ASK_INSTALL")), "true")
  if (can_prompt) {
    reason_str <- if (!is.null(reason) && nzchar(reason)) paste0(" (", reason, ")") else ""
    cat(sprintf("\n[testthat] Package '%s' is required for this test%s.\n", pkg, reason_str))
    ans <- tryCatch(
      readline(prompt = sprintf("Would you like to install package '%s' now? [y/N]: ", pkg)),
      error = function(e) "n"
    )
    if (tolower(trimws(ans)) %in% c("y", "yes")) {
      message(sprintf("Installing package '%s'...", pkg))
      tryCatch({
        utils::install.packages(pkg, repos = "https://cloud.r-project.org")
      }, error = function(e) {
        warning("Failed to install package: ", conditionMessage(e))
      })
      if (requireNamespace(pkg, quietly = TRUE)) {
        if (!is.null(minimum_version) && utils::packageVersion(pkg) < minimum_version) {
          testthat::skip(sprintf("Package '%s' version is < %s", pkg, minimum_version))
        }
        return(invisible(TRUE))
      }
    }
  }

  testthat::skip(sprintf("Package '%s' is not installed", pkg))
}

# Override skip_if_not_installed in test context to ask permission before skipping
skip_if_not_installed <- function(pkg, minimum_version = NULL) {
  ensure_package_installed(pkg, minimum_version = minimum_version)
}
