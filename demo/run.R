#!/usr/bin/env Rscript
# End-to-end paVerse pipeline, headless. Same steps as attrition-report.qmd,
# without the narrative or plots, so this can run as a CI smoke test:
# messy export -> standardize -> validate -> derive -> reconcile -> attrit.
# Exits 0 (via `stop()` on any failed check) iff every stage succeeds.

suppressPackageStartupMessages({
  library(pa.synthetic)
  library(workforce)
  library(attrition)
})

.script_path <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_flag <- grep("^--file=", cmd_args)
  if (length(file_flag)) return(normalizePath(sub("^--file=", "", cmd_args[file_flag])))
  "demo/run.R" # fallback for interactive() sourcing from the repo root
}
here <- dirname(.script_path())
source(file.path(here, "standardize.R"))

cat("== 1. Ingest messy vendor export ==\n")
raw <- padm_demo_raw
cat(sprintf("  %d raw rows, columns: %s\n", nrow(raw), paste(names(raw), collapse = ", ")))

cat("== 2. Standardize to padm pa_event ==\n")
event <- standardize_workday(raw)
stopifnot(all(!is.na(event$event_date)), all(!is.na(event$event_type)))
cat(sprintf("  %d standardized event rows\n", nrow(event)))

cat("== 3. Validate against padm ==\n")
tables <- list(
  pa_person = padm_demo_person,
  pa_event = event,
  pa_org_unit = padm_demo_org_unit,
  pa_job = padm_demo_job
)
v <- padm_validate(tables, level = "extended")
print(v)
if (!v$ok) stop("padm_validate() failed at the 'extended' conformance level")

cat("== 4. Derive assignments ==\n")
assignments <- wf_assignments(event)
cat(sprintf("  %d assignment intervals across %d persons\n",
  nrow(assignments), length(unique(assignments$person_id))))

cat("== 5. Headcount, snapshot, reconciliation ==\n")
snapshot <- wf_snapshot(assignments, period = "month")
reconcile <- wf_reconcile(snapshot, event, period = "month")
checked <- reconcile$reconciled[!is.na(reconcile$reconciled)]
cat(sprintf("  %d/%d periods reconciled\n", sum(checked), length(checked)))
if (!all(checked)) stop("reconciliation invariant failed: opening + hires - exits != closing")

cat("== 6. Turnover rate under three definitions (calendar year 2025) ==\n")
win_from <- as.Date("2025-01-01")
win_to <- as.Date("2026-01-01")
rates <- do.call(rbind, lapply(
  c("beginning_headcount", "avg_headcount", "exposure"),
  function(d) attr_rate(assignments, event, win_from, win_to, definition = d)
))
print(rates)
if (length(unique(round(rates$rate, 4))) < 2) {
  stop("expected the three turnover definitions to disagree on this dataset")
}

cat("== 7. Retention curves and cohort table ==\n")
tenure <- wf_tenure(assignments, as_of = win_to - 1)
curve <- attr_curve(tenure, cohort = "hire_year")
cohort_tbl <- attr_cohort(tenure)
cat(sprintf("  KM curve: %d cohorts, %d points\n", length(unique(curve$group)), nrow(curve)))
cat(sprintf("  cohort table: %d rows\n", nrow(cohort_tbl)))

cat("\nAll stages completed successfully.\n")
