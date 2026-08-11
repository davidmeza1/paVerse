#' Kaplan-Meier retention curve by cohort
#'
#' Fits a Kaplan-Meier survival curve on tenure data (e.g. from
#' `workforce::wf_tenure()`), treating still-active persons as right-censored
#' at their `reference_date` and exited persons as an observed event at their
#' tenure. Grouping by hire-year cohort is what lets you see whether recent
#' cohorts are retaining better or worse than older ones at the same point
#' in their tenure — a comparison a single point-in-time turnover rate
#' cannot make.
#'
#' @param tenure A data frame shaped like `workforce::wf_tenure()`'s output:
#'   `tenure_months`, `is_active`, `hire_date`.
#' @param cohort `"hire_year"` (default) groups by the year of `hire_date`;
#'   `"none"` fits a single curve for all persons.
#' @param max_months Optional integer. If supplied, tenure is administratively
#'   censored at this horizon (capped and marked as censored rather than an
#'   event) so curves for different cohorts are comparable over the same
#'   observation window.
#' @return A tidy data frame: `group`, `time_months`, `n_risk`, `n_event`,
#'   `survival`, `lower`, `upper` (95% CI from `survival::survfit()`).
#' @export
attr_curve <- function(tenure, cohort = c("hire_year", "none"), max_months = NULL) {
  cohort <- match.arg(cohort)

  d <- tenure
  d$status <- as.integer(!d$is_active)
  d$group <- if (cohort == "hire_year") format(d$hire_date, "%Y") else "all"

  if (!is.null(max_months)) {
    capped <- d$tenure_months > max_months
    d$status[capped] <- 0L
    d$tenure_months[capped] <- max_months
  }

  fit <- survival::survfit(survival::Surv(tenure_months, status) ~ group, data = d)
  s <- summary(fit)

  group_labels <- if (!is.null(s$strata)) {
    sub("^group=", "", as.character(s$strata))
  } else {
    rep(unique(d$group), length(s$time))
  }

  data.frame(
    group = group_labels,
    time_months = s$time,
    n_risk = s$n.risk,
    n_event = s$n.event,
    survival = s$surv,
    lower = s$lower,
    upper = s$upper,
    stringsAsFactors = FALSE
  )
}
