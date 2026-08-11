#' Simulate a messy vendor HRIS export
#'
#' Takes a clean `padm` event stream (as produced by [pa_synth_events()]) and
#' re-renders it as a deliberately messy, effective-dated wide export in the
#' shape an analyst would actually receive from an HRIS vendor: renamed
#' columns, inconsistent date formats mixed row by row, inconsistent event
#' text casing, and stray whitespace. This exists so the demo pipeline has a
#' real standardize-to-`padm` step to show, rather than starting from data
#' that is already clean.
#'
#' No information is lost relative to `event` — every quirk is reversible
#' with a documented rule — this is a format problem, not a data-quality
#' problem.
#'
#' @param event A `pa_event` data frame, e.g. from [pa_synth_events()]`$event`.
#' @param vendor One of `"workday"` or `"successfactors"`; controls the
#'   column-naming convention used.
#' @param seed Integer seed controlling which rows get which date format /
#'   casing quirk (reproducible messiness).
#' @return A data frame with vendor-style column names and mixed
#'   formatting — intentionally not `padm`-conforming.
#' @export
pa_synth_raw <- function(event, vendor = c("workday", "successfactors"), seed = 1) {
  vendor <- match.arg(vendor)

  withr::with_seed(seed, {
    n <- nrow(event)
    date_style <- sample(c("iso", "us", "excel"), n, replace = TRUE, prob = c(0.5, 0.35, 0.15))
    fmt_date <- function(d, style) {
      if (is.na(d)) return(NA_character_)
      switch(style,
        iso = format(d, "%Y-%m-%d"),
        us = format(d, "%m/%d/%Y"),
        excel = as.character(as.integer(d) + 25569L)  # days since 1899-12-30 epoch
      )
    }
    event_date_fmt <- vapply(seq_len(n), function(i) fmt_date(event$event_date[i], date_style[i]), character(1))

    case_style <- sample(c("title", "upper", "lower"), n, replace = TRUE)
    reason_text <- ifelse(is.na(event$event_subtype), event$event_type,
                           paste0(event$event_type, " - ", event$event_subtype))
    reason_fmt <- vapply(seq_len(n), function(i) {
      switch(case_style[i],
        title = tools::toTitleCase(gsub("_", " ", reason_text[i])),
        upper = toupper(reason_text[i]),
        lower = tolower(reason_text[i])
      )
    }, character(1))

    pad <- function(x) ifelse(stats::runif(length(x)) < 0.1, paste0("  ", x, "  "), x)

    if (vendor == "workday") {
      out <- data.frame(
        `Worker ID` = event$person_id,
        `Effective Date` = event_date_fmt,
        `Event Reason` = pad(reason_fmt),
        `Supervisory Org` = event$org_unit_id,
        `Position ID` = event$job_id,
        `Manager Worker ID` = event$manager_person_id,
        `FTE %` = ifelse(is.na(event$fte), NA_character_, paste0(event$fte * 100, "%")),
        `Annual Salary` = event$base_pay_amount,
        `Currency` = event$base_pay_currency,
        `Regretted Flag` = ifelse(is.na(event$is_regretted), "", ifelse(event$is_regretted, "Y", "N")),
        `Source System ID` = event$source_system,
        check.names = FALSE, stringsAsFactors = FALSE
      )
    } else {
      out <- data.frame(
        `PERNR` = event$person_id,
        `Effective_Date` = event_date_fmt,
        `Action_Reason` = pad(reason_fmt),
        `Org_Unit` = event$org_unit_id,
        `Job_Code` = event$job_id,
        `Manager_PERNR` = event$manager_person_id,
        `FTE` = event$fte,
        `Base_Salary` = event$base_pay_amount,
        `Curr` = event$base_pay_currency,
        `Regretted` = ifelse(is.na(event$is_regretted), "", ifelse(event$is_regretted, "Yes", "No")),
        `Src` = event$source_system,
        check.names = FALSE, stringsAsFactors = FALSE
      )
    }

    out
  })
}
