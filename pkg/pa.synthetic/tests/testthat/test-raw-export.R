org <- pa_synth_org(n_units = 10, depth = 2, seed = 4)
jobs <- pa_synth_jobs()
cohort <- pa_synth_cohort(n = 40, start = as.Date("2021-01-01"), end = as.Date("2021-12-31"),
                           org = org, jobs = jobs, seed = 4)
sim <- pa_synth_events(cohort, org, jobs, end_date = as.Date("2022-12-31"), seed = 4)

test_that("pa_synth_raw preserves row count and renames columns per vendor", {
  raw_wd <- pa_synth_raw(sim$event, vendor = "workday")
  expect_equal(nrow(raw_wd), nrow(sim$event))
  expect_true("Worker ID" %in% names(raw_wd))
  expect_true(all(raw_wd$`Worker ID` == sim$event$person_id))

  raw_sf <- pa_synth_raw(sim$event, vendor = "successfactors")
  expect_equal(nrow(raw_sf), nrow(sim$event))
  expect_true("PERNR" %in% names(raw_sf))
})

test_that("pa_synth_raw mixes date formats (not all identical)", {
  raw_wd <- pa_synth_raw(sim$event, vendor = "workday", seed = 1)
  n_formats <- length(unique(nchar(trimws(raw_wd$`Effective Date`))))
  expect_gt(n_formats, 1)
})

test_that("pa_synth_raw is reproducible given a seed", {
  a <- pa_synth_raw(sim$event, vendor = "workday", seed = 8)
  b <- pa_synth_raw(sim$event, vendor = "workday", seed = 8)
  expect_identical(a, b)
})
