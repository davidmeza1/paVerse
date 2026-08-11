test_that("attr_curve produces a monotonically non-increasing survival curve per group", {
  curve <- attr_curve(big_tenure, cohort = "hire_year")
  expect_true(all(c("group", "time_months", "n_risk", "n_event", "survival") %in% names(curve)))

  by_group <- split(curve, curve$group)
  for (g in names(by_group)) {
    surv <- by_group[[g]]$survival[order(by_group[[g]]$time_months)]
    expect_true(all(diff(surv) <= 1e-9), info = paste("group", g))
  }
})

test_that("attr_curve(cohort = 'none') fits a single curve for everyone", {
  curve <- attr_curve(big_tenure, cohort = "none")
  expect_equal(unique(curve$group), "all")
})

test_that("attr_curve respects max_months as an administrative censoring horizon", {
  curve <- attr_curve(big_tenure, cohort = "none", max_months = 24)
  expect_true(all(curve$time_months <= 24))
})

test_that("attr_curve groups by hire year", {
  curve <- attr_curve(big_tenure, cohort = "hire_year")
  expected_years <- sort(unique(format(big_tenure$hire_date, "%Y")))
  expect_setequal(unique(curve$group), expected_years)
})
