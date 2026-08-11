# Builds the cached demo datasets shipped in data/. Re-run and re-document
# whenever a generator in R/ changes. Not part of the installed package.
devtools::load_all(".")

padm_demo_org_unit <- pa_synth_org(n_units = 15, depth = 3, seed = 42)
padm_demo_job <- pa_synth_jobs(seed = 42)

cohort <- pa_synth_cohort(
  n = 600,
  start = as.Date("2019-01-01"),
  end = as.Date("2024-12-31"),
  org = padm_demo_org_unit,
  jobs = padm_demo_job,
  growth_rate = 2.2,
  seed = 42
)

sim <- pa_synth_events(
  cohort = cohort,
  org = padm_demo_org_unit,
  jobs = padm_demo_job,
  end_date = as.Date("2025-12-31"),
  seed = 42,
  adverse_impact = TRUE
)
padm_demo_person <- sim$person
padm_demo_event <- sim$event

padm_demo_raw <- pa_synth_raw(padm_demo_event, vendor = "workday", seed = 42)

usethis::use_data(padm_demo_org_unit, overwrite = TRUE)
usethis::use_data(padm_demo_job, overwrite = TRUE)
usethis::use_data(padm_demo_person, overwrite = TRUE)
usethis::use_data(padm_demo_event, overwrite = TRUE)
usethis::use_data(padm_demo_raw, overwrite = TRUE)
