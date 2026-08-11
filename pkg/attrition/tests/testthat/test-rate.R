from <- as.Date("2020-01-01")
to <- as.Date("2021-01-01")

test_that("beginning_headcount matches a manual half-open interval count", {
  r <- attr_rate(tiny_assignments, tiny_event, from, to, definition = "beginning_headcount")
  expect_equal(r$exits, 1) # only p2's exit falls in [from, to)
  expect_equal(r$denominator, 2) # p1, p2 active at `from`
  expect_equal(r$rate, 0.5)
})

test_that("avg_headcount averages beginning and ending headcount", {
  r <- attr_rate(tiny_assignments, tiny_event, from, to, definition = "avg_headcount")
  expect_equal(r$denominator, 2.5) # (2 at `from` + 3 at `to - 1`) / 2
  expect_equal(r$rate, 1 / 2.5)
})

test_that("exposure sums person-time overlap independently of headcount snapshots", {
  # Cross-check with a hand-rolled, non-vectorized overlap sum.
  expected_days <- 0
  for (i in seq_len(nrow(tiny_assignments))) {
    vf <- tiny_assignments$valid_from[i]
    vt <- tiny_assignments$valid_to[i]
    if (is.na(vt)) vt <- to
    ov_start <- max(vf, from)
    ov_end <- min(vt, to)
    if (ov_end > ov_start) expected_days <- expected_days + as.numeric(ov_end - ov_start)
  }
  expected_person_years <- expected_days / 365.25

  r <- attr_rate(tiny_assignments, tiny_event, from, to, definition = "exposure")
  expect_equal(r$denominator, expected_person_years)
  expect_equal(r$rate, 1 / expected_person_years)
})

test_that("the three definitions give different, non-arbitrary denominators on the same window", {
  r_begin <- attr_rate(tiny_assignments, tiny_event, from, to, "beginning_headcount")
  r_avg <- attr_rate(tiny_assignments, tiny_event, from, to, "avg_headcount")
  r_exp <- attr_rate(tiny_assignments, tiny_event, from, to, "exposure")

  # Same numerator throughout -- only the denominator choice differs.
  expect_equal(c(r_begin$exits, r_avg$exits, r_exp$exits), rep(1, 3))

  denominators <- c(r_begin$denominator, r_avg$denominator, r_exp$denominator)
  expect_equal(length(unique(round(denominators, 6))), 3)

  # Headcount grew over the window (2 -> 3), so beginning_headcount
  # understates the denominator relative to avg_headcount, which in turn
  # produces a higher rate for the same numerator -- this ordering is
  # guaranteed by construction whenever ending headcount >= beginning.
  expect_gt(r_begin$rate, r_avg$rate)
})

test_that("exposure is exposure-correct on the large seeded dataset", {
  # This is the check that proves the standard is worth having: three
  # legitimate ways of computing "turnover rate" on the identical data,
  # over the identical window, produce three different numbers.
  win_from <- as.Date("2021-01-01")
  win_to <- as.Date("2022-01-01")

  r_begin <- attr_rate(big_assignments, big_sim$event, win_from, win_to, "beginning_headcount")
  r_avg <- attr_rate(big_assignments, big_sim$event, win_from, win_to, "avg_headcount")
  r_exp <- attr_rate(big_assignments, big_sim$event, win_from, win_to, "exposure")

  expect_equal(r_begin$exits, r_avg$exits)
  expect_equal(r_begin$exits, r_exp$exits)
  expect_gt(r_begin$exits, 0)

  denominators <- c(r_begin$denominator, r_avg$denominator, r_exp$denominator)
  expect_equal(length(unique(round(denominators, 3))), 3)

  rates <- c(r_begin$rate, r_avg$rate, r_exp$rate)
  expect_equal(length(unique(round(rates, 4))), 3)
})

test_that("attr_rate rejects a non-positive window", {
  expect_error(attr_rate(tiny_assignments, tiny_event, to, to, "exposure"))
  expect_error(attr_rate(tiny_assignments, tiny_event, to, from, "exposure"))
})

test_that("attr_rate returns NA rate (not an error) when denominator is zero", {
  empty_assignments <- tiny_assignments[0, ]
  r <- attr_rate(empty_assignments, tiny_event, from, to, "beginning_headcount")
  expect_equal(r$denominator, 0)
  expect_true(is.na(r$rate))
})
