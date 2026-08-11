# The reconciliation invariant (opening + hires - exits == closing) is the
# central claim of the event-sourced architecture in spec/padm/padm-v0.md
# §1: derived tables can't silently drift because there's only one source
# of truth. Checked across many independently-seeded synthetic datasets,
# plus the large cached pa.synthetic demo dataset as a regression check.

test_that("the reconciliation invariant holds across many seeded datasets", {
  org <- pa.synthetic::pa_synth_org(n_units = 8, depth = 2, seed = 1)
  jobs <- pa.synthetic::pa_synth_jobs()

  for (s in 1:30) {
    cohort <- pa.synthetic::pa_synth_cohort(
      n = 40, start = as.Date("2020-01-01"), end = as.Date("2021-12-31"),
      org = org, jobs = jobs, seed = s
    )
    sim <- pa.synthetic::pa_synth_events(
      cohort, org, jobs, end_date = as.Date("2022-12-31"), seed = s
    )
    asn <- wf_assignments(sim$event)
    snap <- wf_snapshot(asn, period = "month")
    rec <- wf_reconcile(snap, sim$event, period = "month")

    checked <- rec$reconciled[!is.na(rec$reconciled)]
    expect_true(length(checked) > 0, info = paste("seed", s))
    expect_true(all(checked), info = paste("seed", s, "- mismatched periods:",
      paste(rec$period[!is.na(rec$reconciled) & !rec$reconciled], collapse = ", ")))
  }
})

test_that("the reconciliation invariant holds on the large cached demo dataset", {
  asn <- wf_assignments(pa.synthetic::padm_demo_event)
  snap <- wf_snapshot(asn, period = "month")
  rec <- wf_reconcile(snap, pa.synthetic::padm_demo_event, period = "month")

  checked <- rec$reconciled[!is.na(rec$reconciled)]
  expect_gt(length(checked), 50)  # sanity: this dataset spans ~7 years monthly
  expect_true(all(checked))
})
