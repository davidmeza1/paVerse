#' Generate a synthetic hiring cohort
#'
#' Samples `n` hire dates between `start` and `end` from a non-homogeneous
#' Poisson process whose intensity grows linearly over the window (a company
#' growing headcount over time, rather than hiring at a constant rate), then
#' assigns each new hire an entry-level job and a leaf-level org unit.
#'
#' @param n Number of people to generate.
#' @param start,end `Date`. Hiring window.
#' @param org A `pa_org_unit` data frame, e.g. from [pa_synth_org()].
#' @param jobs A `pa_job` data frame, e.g. from [pa_synth_jobs()].
#' @param growth_rate Relative intensity multiplier from `start` to `end`
#'   (2 means twice as many hires/day near `end` as near `start`).
#' @param seed Integer seed for reproducibility.
#' @return A data frame with one row per hired person: `person_id`,
#'   `gender`, `hire_date`, `org_unit_id`, `job_id`. This is an intermediate
#'   structure, not itself a `padm` table — [pa_synth_events()] turns it into
#'   `pa_person` + `pa_event` (hire) rows.
#' @export
pa_synth_cohort <- function(n, start, end, org, jobs, growth_rate = 2, seed = 1) {
  stopifnot(n > 0, end > start)

  withr::with_seed(seed, {
    days <- as.integer(end - start)
    day_idx <- 0:days
    weight <- 1 + (growth_rate - 1) * (day_idx / max(days, 1))
    hire_offsets <- sample(day_idx, n, replace = TRUE, prob = weight)
    hire_date <- sort(start + hire_offsets)

    entry_jobs <- jobs[jobs$job_level == min(jobs$job_level), ]
    family_weight <- c(Engineering = 0.35, Sales = 0.25, Operations = 0.15,
                        Finance = 0.13, People = 0.12)
    fam_probs <- family_weight[entry_jobs$job_family]
    fam_probs <- fam_probs / sum(fam_probs)
    job_id <- sample(entry_jobs$job_id, n, replace = TRUE, prob = fam_probs)

    leaf_level <- max(org$org_unit_level)
    leaf_units <- org$org_unit_id[org$org_unit_level == leaf_level]
    org_unit_id <- sample(leaf_units, n, replace = TRUE)

    gender <- sample(c("F", "M"), n, replace = TRUE)

    data.frame(
      person_id = .new_ids("P", n, width = 6),
      gender = gender,
      hire_date = hire_date,
      org_unit_id = org_unit_id,
      job_id = job_id,
      stringsAsFactors = FALSE
    )
  })
}
