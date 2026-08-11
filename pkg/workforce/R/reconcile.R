#' Reconcile derived headcount against the raw event stream
#'
#' The invariant every workforce data model needs and almost none check
#' automatically: for each period, `opening + hires − exits == closing`,
#' where `opening`/`closing` come from [wf_snapshot()] and `hires`/`exits`
#' are counted directly from `pa_event`. Because `pa_assignment` and
#' `pa_headcount_snapshot` are *derived* from the same event stream
#' (`spec/padm/padm-v0.md` §1), a mismatch here can only mean a bug in the
#' derivation, not two independently-drifting sources of truth.
#'
#' `hire` and `rehire` are both counted as accessions, matching the
#' `category` field in [padm_event_types()]. The first period in the result
#' has no known `opening` (there is no prior snapshot) and is left
#' unreconciled (`reconciled = NA`) rather than silently assumed to balance.
#'
#' @param snapshot A `pa_headcount_snapshot` data frame from [wf_snapshot()].
#' @param event The `pa_event` data frame the snapshot was derived from.
#' @param period Must match the `period` used to build `snapshot`.
#' @return A data frame: `period`, `opening`, `hires`, `exits`,
#'   `expected_closing`, `closing`, `reconciled`.
#' @export
wf_reconcile <- function(snapshot, event, period = c("month", "quarter", "year")) {
  period <- match.arg(period)
  ev_period <- lubridate::floor_date(event$event_date, unit = period)

  vocab <- padm_event_types()
  headcount_affecting <- unique(vocab$event_type[vocab$affects_headcount %in% TRUE])
  accession_types <- unique(vocab$event_type[vocab$category == "accession"])
  separation_types <- unique(vocab$event_type[vocab$category == "separation"])
  stopifnot(all(sort(c(accession_types, separation_types)) == sort(headcount_affecting)))

  hires <- stats::aggregate(
    list(hires = event$event_type %in% accession_types),
    by = list(period = ev_period), FUN = sum
  )
  exits <- stats::aggregate(
    list(exits = event$event_type %in% separation_types),
    by = list(period = ev_period), FUN = sum
  )

  closing <- stats::aggregate(is_active ~ period, data = snapshot, FUN = sum)
  names(closing)[names(closing) == "is_active"] <- "closing"

  out <- merge(closing, hires, by = "period", all.x = TRUE)
  out <- merge(out, exits, by = "period", all.x = TRUE)
  out$hires[is.na(out$hires)] <- 0L
  out$exits[is.na(out$exits)] <- 0L
  out <- out[order(out$period), ]

  out$opening <- c(NA_integer_, utils::head(out$closing, -1))
  out$expected_closing <- out$opening + out$hires - out$exits
  out$reconciled <- ifelse(is.na(out$opening), NA, out$expected_closing == out$closing)

  out[, c("period", "opening", "hires", "exits", "expected_closing", "closing", "reconciled")]
}
