#' Rolling trailing-window turnover rate
#'
#' Computes [attr_rate()] for a trailing window ending at each date in
#' `period_ends`, e.g. a 12-month trailing rate evaluated at every
#' month-end — the standard way to smooth a noisy monthly rate without
#' losing the ability to see a trend develop.
#'
#' @param assignments A `pa_assignment` data frame.
#' @param event A `pa_event` data frame.
#' @param period_ends A vector of `Date`s; each is the exclusive upper bound
#'   (`to`) of one trailing window.
#' @param window_months Integer; width of each trailing window in months.
#'   Default 12.
#' @param definition Passed through to [attr_rate()]. Default `"exposure"`.
#' @return A data frame with one row per element of `period_ends`, same
#'   columns as [attr_rate()].
#' @export
attr_rate_rolling <- function(assignments, event, period_ends, window_months = 12,
                               definition = c("exposure", "avg_headcount", "beginning_headcount")) {
  definition <- match.arg(definition)
  rows <- lapply(period_ends, function(to) {
    from <- lubridate::`%m-%`(to, lubridate::period(window_months, units = "months"))
    attr_rate(assignments, event, from, to, definition = definition)
  })
  res <- do.call(rbind, rows)
  rownames(res) <- NULL
  res
}
