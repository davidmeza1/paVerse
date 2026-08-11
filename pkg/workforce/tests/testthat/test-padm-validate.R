tables_ok <- list(
  pa_person = small_sim$person,
  pa_event = small_sim$event,
  pa_org_unit = small_org,
  pa_job = small_jobs
)

test_that("padm_validate passes conforming synthetic data at core and extended", {
  v_core <- padm_validate(tables_ok, level = "core")
  expect_true(v_core$ok)
  expect_equal(nrow(v_core$failures), 0)

  v_ext <- padm_validate(tables_ok, level = "extended")
  expect_true(v_ext$ok)
  expect_equal(v_ext$achieved_level, "extended")
})

test_that("padm_validate reports a missing required table", {
  tables_missing <- tables_ok
  tables_missing$pa_org_unit <- NULL
  v <- padm_validate(tables_missing, level = "core")
  expect_false(v$ok)
  expect_true("pa_org_unit" %in% v$failures$table)
})

test_that("padm_validate reports a missing required column", {
  tables_bad <- tables_ok
  tables_bad$pa_event$event_date <- NULL
  v <- padm_validate(tables_bad, level = "core")
  expect_false(v$ok)
  expect_true(any(v$failures$table == "pa_event" & v$failures$column == "event_date"))
})

test_that("padm_validate catches an out-of-vocabulary event_type", {
  tables_bad <- tables_ok
  tables_bad$pa_event$event_type[1] <- "made_up_event"
  v <- padm_validate(tables_bad, level = "core")
  expect_false(v$ok)
  expect_true(any(v$failures$table == "pa_event" & v$failures$column == "event_type"))
})

test_that("padm_validate enforces the exit/event_subtype conditional rule", {
  tables_bad <- tables_ok
  exit_rows <- which(tables_bad$pa_event$event_type == "exit")
  tables_bad$pa_event$event_subtype[exit_rows[1]] <- NA
  v <- padm_validate(tables_bad, level = "core")
  expect_false(v$ok)
  expect_true(any(v$failures$column == "event_subtype"))
})

test_that("padm_validate caps achieved_level to what's actually supplied", {
  tables_core_only <- tables_ok
  tables_core_only$pa_job <- NULL
  v <- padm_validate(tables_core_only, level = "core")
  expect_equal(v$achieved_level, "core")
})
