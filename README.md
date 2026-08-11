# paVerse

*A "pharmaverse for people analytics" — a shared data model, and a small set of packages built on
it, so people-analytics teams stop reinventing headcount, tenure, and turnover logic from scratch.*

**Status: a solo proof, not a community project.** There is no charter, no council, no published
packages, and no website. What exists is a runnable pipeline that demonstrates the idea end to
end on synthetic data. See [peopleverse-strategy-plan.md](peopleverse-strategy-plan.md) for the
full strategy and what comes after this proof.

## What's here

```
spec/padm/            padm v0 — the People-Analytics Data Model (RFC + JSON Schema + event vocab)
pkg/pa.synthetic/      seeded synthetic HR data generator, conforming to padm
pkg/workforce/         event stream -> assignments, headcount, tenure, reconciliation (admiral analogue)
pkg/attrition/         standardized turnover metrics, rolling rates, survival curves
demo/                  the reference pipeline: messy export -> padm -> attrition report
```

**The core idea** (`spec/padm/padm-v0.md` §1): workforce history is an immutable stream of events.
Every point-in-time view — who's active today, what someone's tenure is, what headcount was last
March — is *derived* from that stream, never stored as a second source of truth. That's what makes
`opening + hires − exits == closing` a checkable invariant instead of an approximation, and it's
the same architectural bet pharmaverse's `admiral` makes for CDISC clinical data.

## The reference pipeline

```
messy vendor export (pa.synthetic::pa_synth_raw)
  → standardize to padm pa_event
  → padm_validate()                                  [workforce]
  → wf_assignments() -> pa_assignment (SCD-2)         [workforce]
  → wf_snapshot() / wf_reconcile()                    [workforce]
  → attr_rate() under 3 denominator definitions       [attrition]
  → attr_curve() / attr_cohort()                      [attrition]
  → demo/attrition-report.qmd (self-contained HTML)
```

This is also the sharpest concrete argument for why a shared standard is worth having: computed
on identical data over an identical window, "turnover rate" gives three different numbers
depending on an unstated denominator choice (beginning headcount, average headcount, or exposure
time). `padm` makes `exposure` the canonical default — see spec §7 — but every `attrition`
function requires the definition be named explicitly, so a reported number is never ambiguous
about what it measures.

## Running the demo

Requires R (≥ 4.1), the [Quarto CLI](https://quarto.org/docs/get-started/), and `devtools`,
`gt`, `ggplot2`, `dplyr`, `scales`, `survival`, `lubridate`, and `sessioninfo` from CRAN.

```bash
# 1. Install the three packages from source
Rscript -e 'for (p in c("pkg/pa.synthetic", "pkg/workforce", "pkg/attrition")) devtools::install(p, upgrade = FALSE)'

# 2. Run the pipeline headless (CI-style smoke test; exits non-zero on any failed check)
Rscript demo/run.R

# 3. Render the full report with narrative, tables, and plots
quarto render demo/attrition-report.qmd
```

Step 3 produces `demo/attrition-report.html`, self-contained and viewable directly from GitHub or
by opening the file locally.

## Verifying the packages

Each package under `pkg/` is a standard R package with a full test suite:

```bash
Rscript -e 'devtools::test("pkg/workforce")'   # 91 tests
Rscript -e 'devtools::check("pkg/workforce")'  # 0 errors, 0 warnings, 0 notes
```

(same pattern for `pkg/pa.synthetic` and `pkg/attrition`). The `workforce` test suite includes the
reconciliation invariant checked across 30+ independently-seeded synthetic datasets plus the large
cached demo dataset — the single strongest validation that the event-sourced architecture actually
holds.

## Why R first

This proof is R-first for speed of iteration, but `padm` itself is language-neutral: every table
is specified as JSON Schema (`spec/padm/schemas/`), not as an R data structure, so a Python
implementation can be checked against the same contract later rather than promised. See
`peopleverse-strategy-plan.md` §12 for the sequencing (Python parity is the next step after
outside feedback on this proof, not before).

## Not in scope yet

Charter, council, neutral governing home, public website, R-universe/PyPI registration, a
`pa.fairness`/`pa.privacy` package (the sensitivity tiers and adverse-impact signal that would
feed them already exist, tagged and documented, in `spec/padm/` and `pkg/pa.synthetic/`), and
Posit Connect deployment. All deliberately deferred — see
[peopleverse-strategy-plan.md](peopleverse-strategy-plan.md) §12.
