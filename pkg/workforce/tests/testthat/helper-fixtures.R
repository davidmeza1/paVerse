# Shared small fixture used across multiple test files. pa.synthetic is a
# Suggests dependency (workforce doesn't depend on it at runtime) used here
# purely as a test-data generator.
small_org <- pa.synthetic::pa_synth_org(n_units = 8, depth = 2, seed = 100)
small_jobs <- pa.synthetic::pa_synth_jobs()
small_cohort <- pa.synthetic::pa_synth_cohort(
  n = 50, start = as.Date("2021-01-01"), end = as.Date("2022-12-31"),
  org = small_org, jobs = small_jobs, seed = 100
)
small_sim <- pa.synthetic::pa_synth_events(
  small_cohort, small_org, small_jobs, end_date = as.Date("2023-12-31"), seed = 100
)
