#' Tenure as of a reference date
#'
#' Computes each person's tenure from their first assignment (`hire`) to a
#' reference date — their exit date if they have one, capped at `as_of`
#' either way. `as_of` has no default deliberately: a tenure report without
#' an explicit reference date is a report that silently changes every time
#' it's re-run, which defeats the reproducibility goal in
#' `spec/padm/padm-v0.md` §1.
#'
#' @param assignments A `pa_assignment` data frame.
#' @param as_of `Date`. Reference date for still-active persons; ignored
#'   (capped) for persons who already exited before this date.
#' @return A data frame: `person_id`, `hire_date`, `reference_date`,
#'   `is_active` (as of `reference_date`), `tenure_days`, `tenure_months`,
#'   `tenure_years`.
#' @export
wf_tenure <- function(assignments, as_of) {
  by_person <- split(assignments, assignments$person_id)
  rows <- lapply(names(by_person), function(pid) {
    a <- by_person[[pid]]
    a <- a[order(a$valid_from), ]
    hire_date <- a$valid_from[1]
    exit_row <- a[!is.na(a$exit_type), ]
    exited <- nrow(exit_row) > 0
    reference_date <- if (exited) min(exit_row$valid_to[1], as_of) else as_of
    tenure_days <- as.integer(reference_date - hire_date)

    data.frame(
      person_id = pid,
      hire_date = hire_date,
      reference_date = reference_date,
      is_active = !exited,
      tenure_days = tenure_days,
      tenure_months = round(tenure_days / 30.44, 2),
      tenure_years = round(tenure_days / 365.25, 2),
      stringsAsFactors = FALSE
    )
  })
  res <- do.call(rbind, rows)
  rownames(res) <- NULL
  res[order(res$person_id), ]
}
