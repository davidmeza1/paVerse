asn <- wf_assignments(small_sim$event)

test_that("wf_headcount matches a manual half-open interval count", {
  as_of <- as.Date("2022-06-30")
  expected <- sum(asn$valid_from <= as_of & (is.na(asn$valid_to) | asn$valid_to > as_of))
  expect_equal(wf_headcount(asn, as_of), expected)
})

test_that("wf_headcount(exclude_on_leave = TRUE) is never greater than the default", {
  as_of <- as.Date("2022-06-30")
  expect_lte(wf_headcount(asn, as_of, exclude_on_leave = TRUE), wf_headcount(asn, as_of))
})

test_that("wf_snapshot produces a dense person x period grid", {
  snap <- wf_snapshot(asn, period = "month")
  n_persons <- length(unique(asn$person_id))
  n_periods <- length(unique(snap$period))
  expect_equal(nrow(snap), n_persons * n_periods)
  expect_true(all(c("person_id", "period", "is_active") %in% names(snap)))
})

test_that("wf_snapshot headcount at a period matches wf_headcount at that period's end", {
  snap <- wf_snapshot(asn, period = "month")
  target_period <- as.Date("2022-06-01")
  from_snapshot <- sum(snap$is_active[snap$period == target_period])
  from_headcount <- wf_headcount(asn, as_of = as.Date("2022-06-30"))
  expect_equal(from_snapshot, from_headcount)
})
