test_that("attr_rate_rolling returns one row per period end, each a valid trailing window", {
  period_ends <- as.Date(c("2022-06-30", "2022-12-31", "2023-06-30"))
  res <- attr_rate_rolling(big_assignments, big_sim$event, period_ends, window_months = 12)

  expect_equal(nrow(res), length(period_ends))
  expect_equal(res$to, period_ends)
  expect_true(all(res$to - res$from > 300)) # ~12 months, allowing for month-length variation
  expect_true(all(res$definition == "exposure"))
})

test_that("attr_rate_rolling matches a manual attr_rate call for a single window", {
  to <- as.Date("2022-12-31")
  window_months <- 6
  from <- lubridate::`%m-%`(to, lubridate::period(window_months, units = "months"))

  expected <- attr_rate(big_assignments, big_sim$event, from, to, "avg_headcount")
  actual <- attr_rate_rolling(big_assignments, big_sim$event, to,
    window_months = window_months, definition = "avg_headcount"
  )

  expect_equal(actual$rate, expected$rate)
  expect_equal(actual$denominator, expected$denominator)
})

test_that("attr_rate_rolling passes through the requested definition", {
  res <- attr_rate_rolling(big_assignments, big_sim$event, as.Date("2022-12-31"),
    window_months = 12, definition = "beginning_headcount"
  )
  expect_equal(res$definition, "beginning_headcount")
})
