#' Turnover rate over a window, under an explicit denominator definition
#'
#' Every organization computes "turnover rate" differently because the
#' denominator is rarely stated. `attr_rate()` refuses to have a silent
#' default that masks that choice: the definition is a required part of the
#' call, and each one is computed directly from `pa_assignment` intervals so
#' the numbers are internally consistent with each other (see
#' `spec/padm/padm-v0.md` §7).
#'
#' The numerator is always the count of `"exit"` events with `event_date` in
#' the half-open window `[from, to)`. The denominator differs:
#'
#' - `"exposure"` (canonical default) — total person-time contributed by
#'   `assignments` during `[from, to)`, in person-years (sum of per-interval
#'   overlap days / 365.25). The rate is exits per person-year, and is the
#'   only definition that is exposure-correct regardless of when in the
#'   window people joined or left.
#' - `"beginning_headcount"` — active headcount at `from`. Simplest, but
#'   stale before the window even starts in a fast-growing or fast-shrinking
#'   organization.
#' - `"avg_headcount"` — mean of beginning headcount (at `from`) and ending
#'   headcount (at `to - 1`, the last instant covered by the half-open
#'   window). Common in HR reporting; still not exposure-correct for uneven
#'   timing within the window.
#'
#' @param assignments A `pa_assignment` data frame, e.g. from
#'   `workforce::wf_assignments()`.
#' @param event A `pa_event` data frame.
#' @param from,to `Date`. Half-open window `[from, to)`.
#' @param definition One of `"exposure"` (default), `"avg_headcount"`,
#'   `"beginning_headcount"`.
#' @return A one-row data frame: `from`, `to`, `definition`, `exits`,
#'   `denominator`, `rate`.
#' @export
attr_rate <- function(assignments, event, from, to,
                       definition = c("exposure", "avg_headcount", "beginning_headcount")) {
  definition <- match.arg(definition)
  stopifnot(from < to)

  exits <- sum(event$event_type == "exit" &
    event$event_date >= from & event$event_date < to, na.rm = TRUE)

  denominator <- switch(definition,
    beginning_headcount = .headcount_as_of(assignments, from),
    avg_headcount = (.headcount_as_of(assignments, from) +
      .headcount_as_of(assignments, to - 1)) / 2,
    exposure = .person_years(assignments, from, to)
  )

  rate <- if (is.na(denominator) || denominator == 0) NA_real_ else exits / denominator

  data.frame(
    from = from, to = to, definition = definition,
    exits = exits, denominator = denominator, rate = rate,
    stringsAsFactors = FALSE
  )
}

.headcount_as_of <- function(assignments, as_of) {
  sum(assignments$valid_from <= as_of &
    (is.na(assignments$valid_to) | assignments$valid_to > as_of))
}

# Total person-time in `assignments` overlapping [from, to), in person-years.
# Open intervals (valid_to = NA) are capped at `to`, not treated as infinite.
.person_years <- function(assignments, from, to) {
  end_capped <- assignments$valid_to
  end_capped[is.na(end_capped)] <- to

  overlap_start <- pmax(assignments$valid_from, from)
  overlap_end <- pmin(end_capped, to)
  overlap_days <- as.numeric(overlap_end - overlap_start)
  overlap_days[overlap_days < 0] <- 0

  sum(overlap_days) / 365.25
}
