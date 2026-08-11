test_that("attr_cohort produces one row per cohort x checkpoint", {
  checkpoints <- c(3, 6, 12)
  res <- attr_cohort(big_tenure, checkpoints_months = checkpoints)

  n_cohorts <- length(unique(format(big_tenure$hire_date, "%Y")))
  expect_equal(nrow(res), n_cohorts * length(checkpoints))
  expect_true(all(res$checkpoint_months %in% checkpoints))
})

test_that("attr_cohort retention is a proper fraction, bounded by n_observable <= n", {
  res <- attr_cohort(big_tenure)
  expect_true(all(res$n_observable <= res$n))
  observed <- res[!is.na(res$retention), ]
  expect_true(all(observed$retention >= 0 & observed$retention <= 1))
})

test_that("attr_cohort excludes not-yet-observable persons rather than counting them as churned", {
  # A cohort hired in the same year as `as_of` (2023) can't be observable at
  # a 24-month checkpoint for anyone still active -- only exits count there.
  res <- attr_cohort(big_tenure, checkpoints_months = 24)
  latest_cohort <- max(format(big_tenure$hire_date, "%Y"))
  row <- res[res$cohort == latest_cohort, ]
  still_active_uncensored <- sum(
    big_tenure$is_active[format(big_tenure$hire_date, "%Y") == latest_cohort] &
      big_tenure$tenure_months[format(big_tenure$hire_date, "%Y") == latest_cohort] < 24
  )
  expect_equal(row$n - row$n_observable, still_active_uncensored)
})

test_that("attr_cohort retention decreases (or holds) as the checkpoint horizon lengthens", {
  res <- attr_cohort(big_tenure, checkpoints_months = c(3, 12, 36))
  by_cohort <- split(res, res$cohort)
  for (cy in names(by_cohort)) {
    d <- by_cohort[[cy]][order(by_cohort[[cy]]$checkpoint_months), ]
    complete <- d[!is.na(d$retention), ]
    if (nrow(complete) > 1) {
      expect_true(all(diff(complete$retention) <= 1e-9), info = paste("cohort", cy))
    }
  }
})
