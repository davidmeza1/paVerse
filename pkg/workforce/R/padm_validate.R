#' @keywords internal
.padm_conformance_order <- c(core = 1L, extended = 2L, full = 3L)

#' @keywords internal
.padm_schema <- function(table_name) {
  path <- system.file("extdata", "padm", "schemas", paste0(table_name, ".schema.json"),
                       package = "workforce")
  if (!nzchar(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

#' @keywords internal
.padm_required_tables <- function(level) {
  lvl <- .padm_conformance_order[[level]]
  tables <- c("pa_person", "pa_event", "pa_org_unit")
  if (lvl >= .padm_conformance_order[["extended"]]) tables <- c(tables, "pa_job")
  if (lvl >= .padm_conformance_order[["full"]]) tables <- c(tables, "pa_position")
  tables
}

#' Validate source tables against a padm conformance level
#'
#' Checks a named list of source tables (`pa_person`, `pa_event`,
#' `pa_org_unit`, and optionally `pa_job`/`pa_position`) against the padm v0
#' schemas shipped in `inst/extdata/padm/schemas/` (kept in sync with
#' `spec/padm/schemas/`): required tables present, required columns present
#' at the requested conformance level, controlled-vocabulary values for
#' `event_type`/`event_subtype`, and the two conditional-required rules from
#' the `pa_event` schema (`event_subtype` required when `event_type ==
#' "exit"`; `base_pay_currency` required whenever `base_pay_amount` is
#' non-missing).
#'
#' This is intentionally schema-driven rather than a hardcoded duplicate of
#' the spec, so a change to `spec/padm/schemas/*.json` only needs re-copying
#' into `inst/extdata/`, not a second hand-written check.
#'
#' @param tables A named list of data frames, e.g.
#'   `list(pa_person = ..., pa_event = ..., pa_org_unit = ...)`.
#' @param level Requested conformance level: `"core"`, `"extended"`, or
#'   `"full"`. See `spec/padm/padm-v0.md` §6.
#' @return An object of class `padm_validation`: a list with `requested_level`,
#'   `achieved_level` (the highest level actually satisfied, possibly lower
#'   than requested, or `NA` if even `"core"` fails), `ok` (logical: whether
#'   the achieved level meets or exceeds the requested one), and `failures`
#'   (a data frame of `table`, `column`, `issue`).
#' @export
padm_validate <- function(tables, level = c("core", "extended", "full")) {
  level <- match.arg(level)
  failures <- data.frame(table = character(0), column = character(0),
                          issue = character(0), stringsAsFactors = FALSE)
  add_failure <- function(table, column, issue) {
    failures[nrow(failures) + 1L, ] <<- list(table, column, issue)
  }

  achieved <- NA_character_
  for (candidate in names(.padm_conformance_order)[order(.padm_conformance_order)]) {
    candidate_failures <- .padm_check_level(tables, candidate, add_failure_fn = NULL)
    if (length(candidate_failures) == 0L) {
      achieved <- candidate
    } else {
      break
    }
  }

  # re-run at the requested level to populate the reported failures
  requested_failures <- .padm_check_level(tables, level, add_failure_fn = add_failure)

  structure(
    list(
      requested_level = level,
      achieved_level = achieved,
      ok = length(requested_failures) == 0L,
      failures = failures
    ),
    class = "padm_validation"
  )
}

#' @keywords internal
.padm_check_level <- function(tables, level, add_failure_fn = NULL) {
  issues <- character(0)
  note <- function(table, column, issue) {
    issues <<- c(issues, paste(table, column, issue))
    if (!is.null(add_failure_fn)) add_failure_fn(table, column, issue)
  }

  for (tbl in .padm_required_tables(level)) {
    if (is.null(tables[[tbl]])) {
      note(tbl, NA_character_, "required table is missing")
      next
    }
    schema <- .padm_schema(tbl)
    if (is.null(schema)) next
    df <- tables[[tbl]]
    for (col in names(schema$properties)) {
      prop <- schema$properties[[col]]
      col_level <- prop$`x-padm-conformance`
      if (is.null(col_level)) col_level <- schema$`x-padm-conformance`
      if (is.null(col_level)) col_level <- "core"
      if (.padm_conformance_order[[col_level]] > .padm_conformance_order[[level]]) next
      required <- isTRUE(prop$`x-padm-required`) || (col %in% unlist(schema$required %||% list()))
      if (!required) next
      if (!(col %in% names(df))) {
        note(tbl, col, "required column is missing")
        next
      }
      if (!is.null(prop$enum)) {
        allowed <- unlist(Filter(Negate(is.null), prop$enum))
        observed <- unique(df[[col]])
        observed <- observed[!is.na(observed)]
        bad <- setdiff(observed, allowed)
        if (length(bad)) {
          note(tbl, col, paste0("values outside controlled vocabulary: ", paste(bad, collapse = ", ")))
        }
      }
    }

    if (tbl == "pa_event" && "event_type" %in% names(df) && "event_subtype" %in% names(df)) {
      bad <- df$event_type == "exit" & is.na(df$event_subtype)
      if (any(bad, na.rm = TRUE)) {
        note(tbl, "event_subtype", "required when event_type == 'exit'")
      }
    }
    if (tbl == "pa_event" && "base_pay_amount" %in% names(df) && "base_pay_currency" %in% names(df)) {
      bad <- !is.na(df$base_pay_amount) & is.na(df$base_pay_currency)
      if (any(bad, na.rm = TRUE)) {
        note(tbl, "base_pay_currency", "required whenever base_pay_amount is non-missing")
      }
    }
  }

  issues
}

#' @keywords internal
`%||%` <- function(x, y) if (is.null(x)) y else x

#' @export
print.padm_validation <- function(x, ...) {
  status <- if (x$ok) "PASS" else "FAIL"
  cat(sprintf("<padm_validation> requested: %s | achieved: %s | %s\n",
              x$requested_level, x$achieved_level %||% "none", status))
  if (nrow(x$failures)) {
    cat("Failures:\n")
    for (i in seq_len(nrow(x$failures))) {
      f <- x$failures[i, ]
      col <- if (is.na(f$column)) "" else paste0(" $", f$column)
      cat(sprintf("  - %s%s: %s\n", f$table, col, f$issue))
    }
  }
  invisible(x)
}
