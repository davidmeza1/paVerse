org <- pa_synth_org(n_units = 12, depth = 3, seed = 2)
jobs <- pa_synth_jobs()
cohort <- pa_synth_cohort(n = 80, start = as.Date("2020-01-01"), end = as.Date("2021-12-31"),
                           org = org, jobs = jobs, seed = 2)

test_that("pa_synth_cohort produces one row per person with valid FKs", {
  expect_equal(nrow(cohort), 80)
  expect_equal(length(unique(cohort$person_id)), 80)
  expect_true(all(cohort$org_unit_id %in% org$org_unit_id))
  expect_true(all(cohort$job_id %in% jobs$job_id))
})

test_that("pa_synth_events emits exactly one hire per person and preserves keys", {
  sim <- pa_synth_events(cohort, org, jobs, end_date = as.Date("2023-12-31"), seed = 2)

  hires <- sim$event[sim$event$event_type == "hire", ]
  expect_equal(nrow(hires), 80)
  expect_equal(sort(hires$person_id), sort(cohort$person_id))
  expect_equal(length(unique(sim$event$event_id)), nrow(sim$event))

  # every event references a person that exists
  expect_true(all(sim$event$person_id %in% sim$person$person_id))

  # at most one exit per person, and it's the last event for that person
  exits <- sim$event[sim$event$event_type == "exit", ]
  expect_equal(length(exits$person_id), length(unique(exits$person_id)))

  last_event_is_exit <- vapply(exits$person_id, function(p) {
    person_events <- sim$event[sim$event$person_id == p, ]
    person_events <- person_events[order(person_events$event_date), ]
    identical(tail(person_events$event_type, 1), "exit")
  }, logical(1))
  expect_true(all(last_event_is_exit))
})

test_that("exit event_subtype is always populated, per the padm conditional-required rule", {
  sim <- pa_synth_events(cohort, org, jobs, end_date = as.Date("2023-12-31"), seed = 3)
  exits <- sim$event[sim$event$event_type == "exit", ]
  expect_true(all(!is.na(exits$event_subtype)))
  expect_true(all(exits$event_subtype %in%
    c("voluntary", "involuntary", "retirement", "end_of_contract", "death")))
})

test_that("base_pay_amount is never populated without base_pay_currency", {
  sim <- pa_synth_events(cohort, org, jobs, end_date = as.Date("2023-12-31"), seed = 2)
  has_pay <- !is.na(sim$event$base_pay_amount)
  expect_true(all(!is.na(sim$event$base_pay_currency[has_pay])))
})

test_that("pa_synth_events is reproducible given a seed", {
  a <- pa_synth_events(cohort, org, jobs, end_date = as.Date("2022-12-31"), seed = 5)
  b <- pa_synth_events(cohort, org, jobs, end_date = as.Date("2022-12-31"), seed = 5)
  expect_identical(a, b)
})

test_that("adverse_impact = TRUE measurably lowers Engineering promotion rate for gender F", {
  # A promotion adverse-impact signal is a small effect on a low-frequency
  # event, so it only reads clearly at demo scale (~600 people, ~7 years) —
  # the cached demo dataset (data-raw/build_demo_data.R, seed 42) is exactly
  # that scale, so this also regression-tests that the shipped data still
  # carries the documented signal (see ?padm_demo_data).
  fam_by_job <- setNames(padm_demo_job$job_family, padm_demo_job$job_id)
  job_at_hire <- setNames(
    padm_demo_event$job_id[padm_demo_event$event_type == "hire"],
    padm_demo_event$person_id[padm_demo_event$event_type == "hire"]
  )
  gender_by_person <- setNames(padm_demo_person$gender, padm_demo_person$person_id)
  started_eng <- names(job_at_hire)[fam_by_job[job_at_hire] == "Engineering"]

  promo_person <- padm_demo_event$person_id[padm_demo_event$event_type == "promotion"]
  eng_promo <- promo_person[promo_person %in% started_eng]

  f_rate <- length(eng_promo[gender_by_person[eng_promo] == "F"]) /
    sum(gender_by_person[started_eng] == "F")
  m_rate <- length(eng_promo[gender_by_person[eng_promo] == "M"]) /
    sum(gender_by_person[started_eng] == "M")

  expect_true(m_rate > 0)
  expect_lt(f_rate / m_rate, 0.8)  # four-fifths rule violation, by construction
})
