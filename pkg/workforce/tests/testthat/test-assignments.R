test_that("wf_assignments opens exactly one interval per hire and closes on exit", {
  asn <- wf_assignments(small_sim$event)
  n_hires <- sum(small_sim$event$event_type == "hire")
  n_exits <- sum(small_sim$event$event_type == "exit")

  expect_equal(length(unique(asn$person_id)), n_hires)

  by_person <- split(asn, asn$person_id)
  n_open <- sum(vapply(by_person, function(a) sum(is.na(a$valid_to)), integer(1)))
  n_exited <- sum(vapply(by_person, function(a) sum(!is.na(a$exit_type)), integer(1)))
  expect_equal(n_exited, n_exits)
  expect_equal(n_open, n_hires - n_exits)  # every non-exited person has exactly one open interval
})

test_that("wf_assignments intervals never overlap within a person", {
  asn <- wf_assignments(small_sim$event)
  by_person <- split(asn, asn$person_id)
  no_overlap <- vapply(by_person, function(a) {
    a <- a[order(a$valid_from), ]
    if (nrow(a) < 2) return(TRUE)
    all(a$valid_from[-1] >= a$valid_to[-nrow(a)], na.rm = TRUE)
  }, logical(1))
  expect_true(all(no_overlap))
})

test_that("is_on_leave is TRUE only for intervals opened by leave_start", {
  asn <- wf_assignments(small_sim$event)
  leave_starts <- sum(small_sim$event$event_type == "leave_start")
  expect_equal(sum(asn$is_on_leave), leave_starts)
})
