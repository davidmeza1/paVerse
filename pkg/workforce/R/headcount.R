#' Active headcount as of a date
#'
#' Counts assignment rows active as of `as_of`, using the half-open interval
#' convention `[valid_from, valid_to)` from `spec/padm/padm-v0.md` §4: a
#' person is active if `valid_from <= as_of` and (`valid_to` is `NA` or
#' `valid_to > as_of`).
#'
#' @param assignments A `pa_assignment` data frame, e.g. from
#'   [wf_assignments()].
#' @param as_of `Date`.
#' @param exclude_on_leave Logical; if `TRUE`, persons on leave as of
#'   `as_of` are not counted as active. Default `FALSE` (on-leave counts as
#'   active headcount, which is the more common HR reporting convention).
#' @return An integer count.
#' @export
wf_headcount <- function(assignments, as_of, exclude_on_leave = FALSE) {
  active <- assignments$valid_from <= as_of &
    (is.na(assignments$valid_to) | assignments$valid_to > as_of)
  if (exclude_on_leave) active <- active & !assignments$is_on_leave
  sum(active)
}

#' Person-by-period headcount snapshot
#'
#' Produces `pa_headcount_snapshot` (`spec/padm/padm-v0.md` §3.2): one row
#' per person per period, with activity and assignment state evaluated as of
#' the **end** of each period. This is the only place `workforce` produces a
#' dense person-by-period grid — everything upstream is event-sparse.
#'
#' @param assignments A `pa_assignment` data frame.
#' @param period One of `"month"`, `"quarter"`, `"year"`.
#' @param from,to `Date`, inclusive period-start bounds. Default to the
#'   range spanned by `assignments` (earliest `valid_from` to the latest of
#'   any `valid_from`/`valid_to`).
#' @param exclude_on_leave Logical; see [wf_headcount()].
#' @return A `pa_headcount_snapshot` data frame: `person_id`, `period`
#'   (period start date), `is_active`, `org_unit_id`, `job_id`, `fte`.
#' @export
wf_snapshot <- function(assignments, period = c("month", "quarter", "year"),
                         from = NULL, to = NULL, exclude_on_leave = FALSE) {
  period <- match.arg(period)
  if (is.null(from)) from <- min(assignments$valid_from)
  if (is.null(to)) {
    ends <- assignments$valid_to[!is.na(assignments$valid_to)]
    to <- max(c(assignments$valid_from, ends))
  }

  period_starts <- seq(lubridate::floor_date(from, period), lubridate::floor_date(to, period),
                        by = period)
  period_end <- lubridate::ceiling_date(period_starts, unit = period) - 1

  by_person <- split(assignments, assignments$person_id)
  rows <- lapply(names(by_person), function(pid) {
    a <- by_person[[pid]]
    a <- a[order(a$valid_from), ]
    idx <- findInterval(period_end, a$valid_from)
    has_interval <- idx > 0
    at <- pmax(idx, 1)
    valid_to_at <- a$valid_to[at]
    still_open <- is.na(valid_to_at) | valid_to_at > period_end
    is_active <- has_interval & still_open
    on_leave <- has_interval & a$is_on_leave[at]
    if (exclude_on_leave) is_active <- is_active & !on_leave

    data.frame(
      person_id = pid,
      period = period_starts,
      is_active = is_active,
      org_unit_id = ifelse(is_active, a$org_unit_id[at], NA_character_),
      job_id = ifelse(is_active, a$job_id[at], NA_character_),
      fte = ifelse(is_active, a$fte[at], NA_real_),
      stringsAsFactors = FALSE
    )
  })

  res <- do.call(rbind, rows)
  rownames(res) <- NULL
  res[order(res$period, res$person_id), ]
}
