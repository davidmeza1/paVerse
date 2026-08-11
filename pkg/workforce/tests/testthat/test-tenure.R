asn <- wf_assignments(small_sim$event)

test_that("wf_tenure caps exited persons at their exit date, not as_of", {
  as_of <- as.Date("2023-12-31")
  tenure <- wf_tenure(asn, as_of)

  exited_ids <- unique(asn$person_id[!is.na(asn$exit_type)])
  one_exited <- exited_ids[1]
  hire_date <- min(asn$valid_from[asn$person_id == one_exited])
  exit_date <- asn$valid_to[asn$person_id == one_exited & !is.na(asn$exit_type)][1]

  row <- tenure[tenure$person_id == one_exited, ]
  expect_false(row$is_active)
  expect_equal(row$reference_date, exit_date)
  expect_equal(row$tenure_days, as.integer(exit_date - hire_date))
})

test_that("wf_tenure uses as_of for still-active persons", {
  as_of <- as.Date("2023-12-31")
  tenure <- wf_tenure(asn, as_of)
  active_ids <- unique(asn$person_id[is.na(asn$valid_to)])
  row <- tenure[tenure$person_id == active_ids[1], ]
  expect_true(row$is_active)
  expect_equal(row$reference_date, as_of)
})

test_that("tenure_years is internally consistent with tenure_days", {
  tenure <- wf_tenure(asn, as.Date("2023-12-31"))
  expect_equal(tenure$tenure_years, round(tenure$tenure_days / 365.25, 2))
})
