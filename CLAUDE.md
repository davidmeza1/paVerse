# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A solo proof of a "pharmaverse for people analytics": a language-neutral data model (`padm`) plus three R packages and a demo pipeline, all on synthetic data. Not a community project yet — no published packages, charter, or site. `peopleverse-strategy-plan.md` has the strategy; §12 covers what is deliberately deferred.

## Commands

Requires R ≥ 4.1, `devtools`, and the Quarto CLI (for the report only). Run from the repo root.

```bash
# Install all three packages from source (required before running the demo; install order doesn't matter)
Rscript -e 'for (p in c("pkg/pa.synthetic", "pkg/workforce", "pkg/attrition")) devtools::install(p, upgrade = FALSE)'

# Test / check one package (swap the path for pkg/pa.synthetic or pkg/attrition)
Rscript -e 'devtools::test("pkg/workforce")'
Rscript -e 'devtools::check("pkg/workforce")'      # expected: 0 errors, 0 warnings, 0 notes

# Single test file
Rscript -e 'devtools::test("pkg/workforce", filter = "reconcile")'   # runs test-reconcile.R

# Regenerate Rd/NAMESPACE after editing roxygen comments
Rscript -e 'devtools::document("pkg/workforce")'

# End-to-end smoke test (stops with non-zero exit on any failed check) and full report
Rscript demo/run.R
quarto render demo/attrition-report.qmd            # writes demo/attrition-report.html (committed on purpose)
```

`demo/` uses the *installed* packages, not the source tree, so reinstall after changing package code before re-running it.

## Architecture

**Event-sourced spine.** Workforce history is an immutable `pa_event` stream; every point-in-time view (assignments, headcount, tenure, rates) is *derived* from it and never stored as a second source of truth. This is what makes `opening + hires − exits == closing` a checkable invariant (`wf_reconcile()`), and the `workforce` tests assert it across 30+ seeded datasets. Keep that property intact when changing event handling. Full rationale is in `spec/padm/padm-v0.md` §1.

**Pipeline and package roles** (data flows left to right):

```
pa.synthetic  →  standardize (demo/)  →  workforce  →  attrition
raw export       raw → pa_event           validate → wf_assignments (SCD-2)    attr_rate / attr_curve / attr_cohort
                                          → wf_snapshot → wf_reconcile
```

- `pa.synthetic` — seeded generator of padm-conforming tables plus `pa_synth_raw()`, a deliberately messy vendor-style export. Seeded data is cached in `data/` (built by `data-raw/build_demo_data.R`); the `.rda` files are generated, don't hand-edit.
- `workforce` — `padm_validate()` (conformance levels), event → `pa_assignment`, headcount snapshots, tenure, reconciliation.
- `attrition` — turnover metrics on `pa_assignment`/events. `workforce` and `pa.synthetic` are only in `Suggests` (used by tests/examples), so `attrition` code must not depend on them at runtime.
- `demo/standardize.R` is the vendor-specific mapping (raw Workday-like export → `pa_event`); `run.R` and `attrition-report.qmd` run the same steps, the former headless.

**`padm` is the contract, and it is language-neutral.** The source of truth is `spec/padm/` (RFC markdown, JSON Schemas, event-type vocab CSV), not any R structure, so a future Python implementation can be checked against the same schemas.

**Duplicated spec artifacts must be kept in sync by hand.** For v0 the schemas and vocab are copied into packages (a standalone `padm` package will replace this):

- `spec/padm/schemas/*.json` ↔ `pkg/workforce/inst/extdata/padm/schemas/`
- `spec/padm/vocab/event-types.csv` ↔ `pkg/workforce/inst/extdata/padm/vocab/` and `pkg/pa.synthetic/inst/extdata/event-types.csv`

Edit `spec/padm/` first, then copy to every location above (currently they are byte-identical). Silent drift is the failure mode `workforce/R/vocab.R` explicitly calls out.

## Conventions that matter

- **Turnover denominator is never implicit.** `attr_rate()` takes a required `definition` (`"beginning_headcount"`, `"avg_headcount"`, `"exposure"`); the same data yields three different rates. `exposure` is padm's canonical default (spec §7). Don't add a defaulted denominator or an API that hides which one was used.
- Spec §5 defines sensitivity tiers and §6 conformance levels (`padm_validate(level = ...)`); new columns or tables need a tier tag and a schema update, not just code.
- Docs are roxygen-generated (`man/*.Rd`, `NAMESPACE`); edit the `#'` comments, then run `devtools::document()`.
