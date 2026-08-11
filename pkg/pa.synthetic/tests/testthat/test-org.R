test_that("pa_synth_org builds a valid tree", {
  org <- pa_synth_org(n_units = 15, depth = 3, seed = 1)

  expect_equal(nrow(org), 15)
  expect_equal(length(unique(org$org_unit_id)), 15)
  expect_equal(sum(org$org_unit_level == 1), 1)
  expect_true(is.na(org$parent_org_unit_id[org$org_unit_level == 1]))
  expect_true(all(org$parent_org_unit_id[org$org_unit_level > 1] %in% org$org_unit_id))

  # every non-root unit's parent is exactly one level above it
  child_rows <- org[org$org_unit_level > 1, ]
  parent_level <- org$org_unit_level[match(child_rows$parent_org_unit_id, org$org_unit_id)]
  expect_true(all(parent_level == child_rows$org_unit_level - 1))
})

test_that("pa_synth_org is reproducible given a seed", {
  a <- pa_synth_org(n_units = 10, depth = 2, seed = 7)
  b <- pa_synth_org(n_units = 10, depth = 2, seed = 7)
  expect_identical(a, b)
})

test_that("pa_synth_jobs produces a 5x5 ladder", {
  jobs <- pa_synth_jobs()
  expect_equal(nrow(jobs), 25)
  expect_equal(length(unique(jobs$job_family)), 5)
  expect_true(all(jobs$job_level %in% 1:5))
})
