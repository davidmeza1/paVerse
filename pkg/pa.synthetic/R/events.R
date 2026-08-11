#' Simulate a workforce event stream
#'
#' The main generator. Takes a hiring cohort (from [pa_synth_cohort()]) and
#' simulates each person's tenure month by month until they exit or the
#' simulation window ends, producing a full `padm` event stream: hires,
#' promotions, transfers, lateral moves, manager changes, pay changes,
#' leaves, and exits.
#'
#' **Exit hazard** is tenure-shaped, not constant: it peaks between roughly
#' month 6 and month 18 (the well-documented early-tenure flight-risk
#' window), is modulated by a persistent per-manager quality factor
#' (some managers really do have higher attrition on their teams), and is
#' suppressed for ~3 months after a pay change (a raise measurably reduces
#' near-term flight risk).
#'
#' **Documented adverse-impact signal.** When `adverse_impact = TRUE`
#' (the default), promotion probability for `gender == "F"` within the
#' `"Engineering"` job family is multiplied by [ADVERSE_IMPACT_FACTOR], which
#' is set below the four-fifths (80%) threshold used in adverse-impact
#' testing. This is a deliberate, documented data-quality feature — it gives
#' a future `pa.fairness` package something real to detect, and it is not
#' present anywhere else in the simulation. Do not mistake the presence of
#' this signal for a claim about real-world promotion practices; it exists
#' solely as a synthetic teaching/testing fixture.
#'
#' @param cohort A data frame from [pa_synth_cohort()].
#' @param org A `pa_org_unit` data frame.
#' @param jobs A `pa_job` data frame.
#' @param end_date `Date`. Simulation horizon; anyone still employed at this
#'   date is right-censored (no exit event).
#' @param seed Integer seed for reproducibility.
#' @param adverse_impact Logical; whether to embed the documented promotion
#'   adverse-impact signal (see Details). Default `TRUE`.
#' @return A list with two `padm` source tables: `person` (`pa_person`) and
#'   `event` (`pa_event`).
#' @export
pa_synth_events <- function(cohort, org, jobs, end_date, seed = 1, adverse_impact = TRUE) {
  withr::with_seed(seed, {
    leaf_units <- org$org_unit_id[org$org_unit_level == max(org$org_unit_level)]
    max_level_by_family <- tapply(jobs$job_level, jobs$job_family, max)

    roster <- list()   # org_unit_id -> character vector of currently active person_id
    manager_factor <- stats::setNames(numeric(0), character(0))  # named by person_id, persistent "quality" multiplier once they manage
    events <- vector("list", 0L)
    ev_i <- 0L
    add_event <- function(row) {
      ev_i <<- ev_i + 1L
      events[[ev_i]] <<- row
    }

    base_pay_level <- c(`1` = 55000, `2` = 75000, `3` = 95000, `4` = 120000, `5` = 150000)
    family_mult <- c(Engineering = 1.15, Sales = 1.00, Operations = 0.95,
                      Finance = 1.05, People = 0.95)

    cohort <- cohort[order(cohort$hire_date), ]

    for (r in seq_len(nrow(cohort))) {
      pid <- cohort$person_id[r]
      unit0 <- cohort$org_unit_id[r]
      job0 <- cohort$job_id[r]
      gender <- cohort$gender[r]
      hire_date <- cohort$hire_date[r]
      fam0 <- jobs$job_family[jobs$job_id == job0]
      level0 <- jobs$job_level[jobs$job_id == job0]

      active_here <- roster[[unit0]]
      manager0 <- if (length(active_here)) sample(active_here, 1L) else NA_character_
      if (!is.na(manager0) && is.na(manager_factor[manager0])) {
        manager_factor[manager0] <- stats::rlnorm(1, meanlog = 0, sdlog = 0.3)
      }

      pay0 <- base_pay_level[as.character(level0)] * family_mult[[fam0]] * stats::rnorm(1, 1, 0.05)

      add_event(data.frame(
        event_id = NA_character_, person_id = pid, event_date = hire_date,
        event_type = "hire", event_subtype = NA_character_, is_regretted = NA,
        org_unit_id = unit0, job_id = job0, manager_person_id = manager0,
        fte = 1.0, base_pay_amount = round(pay0, 2), base_pay_currency = "USD",
        source_system = "synthetic_hris", stringsAsFactors = FALSE
      ))

      roster[[unit0]] <- c(roster[[unit0]], pid)

      # --- monthly walk ---
      state <- list(unit = unit0, job = job0, family = fam0, level = level0,
                    manager = manager0, pay = pay0, on_leave = FALSE,
                    leave_end = as.Date(NA), last_pay_change = hire_date)

      months <- .month_seq(hire_date, end_date)
      months <- months[-1]  # hire month itself already emitted
      for (m in months) {
        m <- as.Date(m, origin = "1970-01-01")
        tenure_months <- as.integer(round(as.numeric(m - hire_date) / 30.44))

        if (isTRUE(state$on_leave)) {
          if (!is.na(state$leave_end) && m >= state$leave_end) {
            add_event(data.frame(
              event_id = NA_character_, person_id = pid, event_date = m,
              event_type = "leave_end", event_subtype = NA_character_, is_regretted = NA,
              org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
              fte = 1.0, base_pay_amount = NA_real_, base_pay_currency = NA_character_,
              source_system = "synthetic_hris", stringsAsFactors = FALSE
            ))
            state$on_leave <- FALSE
          }
          next
        }

        mgr_mult <- if (!is.na(state$manager) && !is.na(manager_factor[state$manager])) {
          manager_factor[state$manager]
        } else 1.0
        recent_raise <- (m - state$last_pay_change) <= 91
        comp_mult <- if (recent_raise) 0.6 else 1.0
        bump <- exp(-((tenure_months - 12)^2) / (2 * 6^2))
        hazard <- (0.006 + 0.02 * bump) * mgr_mult * comp_mult
        hazard <- .clamp01(hazard)

        if (stats::runif(1) < hazard) {
          subtype <- sample(
            c("voluntary", "involuntary", "retirement", "end_of_contract", "death"),
            1, prob = c(0.68, 0.17, if (tenure_months > 240) 0.05 else 0.0,
                        0.09 + if (tenure_months > 240) 0 else 0.05, 0.01)
          )
          regretted <- if (subtype == "voluntary") {
            sample(c(TRUE, FALSE, NA), 1, prob = c(0.35, 0.45, 0.20))
          } else {
            FALSE
          }
          add_event(data.frame(
            event_id = NA_character_, person_id = pid, event_date = m,
            event_type = "exit", event_subtype = subtype, is_regretted = regretted,
            org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
            fte = 1.0, base_pay_amount = NA_real_, base_pay_currency = NA_character_,
            source_system = "synthetic_hris", stringsAsFactors = FALSE
          ))
          roster[[state$unit]] <- setdiff(roster[[state$unit]], pid)
          break
        }

        # --- non-exit events, at most one per month, priority order ---
        promo_mult <- if (adverse_impact && state$family == "Engineering" && gender == "F") {
          ADVERSE_IMPACT_FACTOR
        } else 1.0
        can_promote <- state$level < max_level_by_family[[state$family]]
        p_promotion <- if (can_promote) 0.008 * promo_mult else 0
        p_transfer <- 0.010
        p_lateral <- 0.004
        p_manager_change <- 0.015
        p_pay_change <- 0.05
        p_leave <- 0.003

        roll <- stats::runif(1)
        cuts <- cumsum(c(p_promotion, p_transfer, p_lateral, p_manager_change,
                          p_pay_change, p_leave))

        if (roll < cuts[1]) {
          new_level <- state$level + 1L
          new_job <- jobs$job_id[jobs$job_family == state$family & jobs$job_level == new_level]
          state$job <- new_job
          state$level <- new_level
          state$pay <- state$pay * stats::runif(1, 1.12, 1.18)
          state$last_pay_change <- m
          add_event(data.frame(
            event_id = NA_character_, person_id = pid, event_date = m,
            event_type = "promotion", event_subtype = NA_character_, is_regretted = NA,
            org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
            fte = 1.0, base_pay_amount = round(state$pay, 2), base_pay_currency = "USD",
            source_system = "synthetic_hris", stringsAsFactors = FALSE
          ))
        } else if (roll < cuts[2]) {
          new_unit <- sample(setdiff(leaf_units, state$unit), 1L)
          roster[[state$unit]] <- setdiff(roster[[state$unit]], pid)
          active_there <- roster[[new_unit]]
          new_manager <- if (length(active_there)) sample(active_there, 1L) else NA_character_
          state$unit <- new_unit
          state$manager <- new_manager
          roster[[new_unit]] <- c(roster[[new_unit]], pid)
          add_event(data.frame(
            event_id = NA_character_, person_id = pid, event_date = m,
            event_type = "transfer", event_subtype = NA_character_, is_regretted = NA,
            org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
            fte = 1.0, base_pay_amount = NA_real_, base_pay_currency = NA_character_,
            source_system = "synthetic_hris", stringsAsFactors = FALSE
          ))
        } else if (roll < cuts[3]) {
          other_families <- setdiff(names(max_level_by_family), state$family)
          new_family <- sample(other_families, 1L)
          candidate_jobs <- jobs$job_id[jobs$job_family == new_family & jobs$job_level == state$level]
          if (length(candidate_jobs)) {
            state$job <- candidate_jobs[1]
            state$family <- new_family
            add_event(data.frame(
              event_id = NA_character_, person_id = pid, event_date = m,
              event_type = "lateral_move", event_subtype = NA_character_, is_regretted = NA,
              org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
              fte = 1.0, base_pay_amount = NA_real_, base_pay_currency = NA_character_,
              source_system = "synthetic_hris", stringsAsFactors = FALSE
            ))
          }
        } else if (roll < cuts[4]) {
          candidates <- setdiff(roster[[state$unit]], pid)
          if (length(candidates)) {
            state$manager <- sample(candidates, 1L)
            if (is.na(manager_factor[state$manager])) {
              manager_factor[state$manager] <- stats::rlnorm(1, meanlog = 0, sdlog = 0.3)
            }
            add_event(data.frame(
              event_id = NA_character_, person_id = pid, event_date = m,
              event_type = "manager_change", event_subtype = NA_character_, is_regretted = NA,
              org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
              fte = 1.0, base_pay_amount = NA_real_, base_pay_currency = NA_character_,
              source_system = "synthetic_hris", stringsAsFactors = FALSE
            ))
          }
        } else if (roll < cuts[5]) {
          state$pay <- state$pay * stats::runif(1, 1.02, 1.06)
          state$last_pay_change <- m
          add_event(data.frame(
            event_id = NA_character_, person_id = pid, event_date = m,
            event_type = "pay_change", event_subtype = NA_character_, is_regretted = NA,
            org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
            fte = 1.0, base_pay_amount = round(state$pay, 2), base_pay_currency = "USD",
            source_system = "synthetic_hris", stringsAsFactors = FALSE
          ))
        } else if (roll < cuts[6]) {
          state$on_leave <- TRUE
          state$leave_end <- m + sample(60:120, 1)
          add_event(data.frame(
            event_id = NA_character_, person_id = pid, event_date = m,
            event_type = "leave_start", event_subtype = NA_character_, is_regretted = NA,
            org_unit_id = state$unit, job_id = state$job, manager_person_id = state$manager,
            fte = 1.0, base_pay_amount = NA_real_, base_pay_currency = NA_character_,
            source_system = "synthetic_hris", stringsAsFactors = FALSE
          ))
        }
      }
    }

    event_df <- do.call(rbind, events)
    event_df$event_id <- .new_ids("EV", nrow(event_df), width = 8)
    rownames(event_df) <- NULL
    event_df <- event_df[order(event_df$person_id, event_df$event_date), ]

    person_df <- data.frame(
      person_id = cohort$person_id,
      birth_date = as.Date(NA),
      gender = cohort$gender,
      ethnicity = NA_character_,
      hire_date_original = cohort$hire_date,
      stringsAsFactors = FALSE
    )

    list(person = person_df, event = event_df)
  })
}

#' Adverse-impact factor applied to Engineering promotion probability for
#' `gender == "F"` when `pa_synth_events(adverse_impact = TRUE)`.
#'
#' Set below the four-fifths (0.8) rule-of-thumb threshold used in
#' adverse-impact testing, so the signal is detectable by design. See
#' [pa_synth_events()] Details.
#'
#' @export
ADVERSE_IMPACT_FACTOR <- 0.55
