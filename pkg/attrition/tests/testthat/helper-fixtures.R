# Hand-built tiny fixture with exactly-known headcount/exposure arithmetic,
# used for exact-value checks in test-rate.R and test-rolling.R.
tiny_assignments <- data.frame(
  person_id = c("p1", "p2", "p3", "p4"),
  valid_from = as.Date(c("2020-01-01", "2020-01-01", "2020-04-01", "2020-09-01")),
  valid_to = as.Date(c(NA, "2020-07-01", NA, NA)),
  stringsAsFactors = FALSE
)
tiny_event <- data.frame(
  event_id = c("e1", "e2"),
  person_id = c("p2", "p3"),
  event_date = as.Date(c("2020-07-01", "2021-06-01")),
  event_type = c("exit", "exit"),
  stringsAsFactors = FALSE
)

# Larger seeded synthetic fixture, used for the cross-definition check and
# for attr_curve()/attr_cohort() (which need enough people to see cohort
# structure). pa.synthetic and workforce are Suggests-only test-data
# generators for attrition, mirroring the pattern in workforce's own tests.
big_org <- pa.synthetic::pa_synth_org(n_units = 8, depth = 2, seed = 200)
big_jobs <- pa.synthetic::pa_synth_jobs()
big_cohort <- pa.synthetic::pa_synth_cohort(
  n = 150, start = as.Date("2019-01-01"), end = as.Date("2022-12-31"),
  org = big_org, jobs = big_jobs, growth_rate = 2, seed = 200
)
big_sim <- pa.synthetic::pa_synth_events(
  big_cohort, big_org, big_jobs, end_date = as.Date("2023-12-31"), seed = 200
)
big_assignments <- workforce::wf_assignments(big_sim$event)
big_tenure <- workforce::wf_tenure(big_assignments, as.Date("2023-12-31"))
