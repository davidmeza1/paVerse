# padm — People-Analytics Data Model

*Version 0.1 (RFC) — August 2026*

`padm` is the shared data model that lets paVerse packages interoperate the way `admiral` and
`teal` interoperate on CDISC SDTM/ADaM in pharmaverse. It is language-neutral: this document is
the contract, [`schemas/`](schemas/) holds JSON Schema for every table, and `workforce` (R) is
the first reference implementation. A conforming Python implementation should be checkable
against the same schemas without reading any R code.

This is v0 — an RFC, not a ratified standard. Feedback changes it. The one thing that should be
hard to change later is the architectural commitment in §1.

---

## 1. Architecture: event-sourced spine, derived snapshots

`padm` treats workforce history as an **immutable stream of events**. Every point-in-time view —
who is active today, what someone's tenure is, what the headcount was last March — is **derived**
from that stream, never stored as a second source of truth.

This is the single most important design decision in `padm`, and it is where most in-house HR
data models go wrong: they store headcount snapshots and assignment tables as independently
maintained facts, which drift out of sync with each other and with the event history that
produced them. An event-sourced spine makes every derived table reconstructable and
reconciliation checkable: `opening + hires + rehires − exits == closing` is either true by
construction or a bug, never "close enough."

Concretely: an organization supplies the **source tables** (§2). `workforce` folds `pa_event`
into **derived tables** (§3). Nothing downstream ever reads a snapshot as ground truth.

## 2. Source tables

What an organization (or `pa.synthetic`) must supply.

### 2.1 `pa_person`

Grain: one row per person. Time-invariant attributes only — anything that changes over time
(job, org, manager, pay) belongs in `pa_event`/`pa_assignment`, not here.

| column | type | tier | required | notes |
|---|---|---|---|---|
| `person_id` | string | 0 | yes | stable, unique, never reused |
| `birth_date` | date | 2 | no | for age-band derivations only; consumers should bucket, not expose |
| `gender` | string | 2 | no | organization-defined categories |
| `ethnicity` | string | 2 | no | organization-defined categories |
| `hire_date_original` | date | 0 | no | first-ever hire date, survives rehire cycles |

### 2.2 `pa_event`

Grain: one row per workforce event. This is the spine.

| column | type | tier | required | notes |
|---|---|---|---|---|
| `event_id` | string | 0 | yes | unique |
| `person_id` | string | 0 | yes | FK → `pa_person` |
| `event_date` | date | 0 | yes | effective date of the change |
| `event_type` | string | 0 | yes | controlled vocabulary, see [`vocab/event-types.csv`](vocab/event-types.csv) |
| `event_subtype` | string | 0 | no | required when `event_type == "exit"` |
| `is_regretted` | logical | 1 | no | orthogonal to subtype; `NA` when not assessed or not applicable |
| `org_unit_id` | string | 0 | conditional | resulting org unit; required for events with `affects_assignment = TRUE` in the vocab table |
| `job_id` | string | 0 | conditional | resulting job |
| `manager_person_id` | string | 1 | conditional | resulting manager |
| `fte` | double | 1 | conditional | resulting FTE, `(0, 1]` |
| `base_pay_amount` | double | 1 | no | resulting base pay |
| `base_pay_currency` | string | 1 | conditional | required whenever `base_pay_amount` is non-missing; ISO 4217 |
| `source_system` | string | 0 | no | provenance |

Events are logically ordered by `(person_id, event_date, event_id)` — `event_id` is the
tiebreaker for same-day events and must sort consistently with intended sequence.

### 2.3 `pa_org_unit`

Grain: one row per org unit per validity interval (SCD-2).

| column | type | tier | required | notes |
|---|---|---|---|---|
| `org_unit_id` | string | 0 | yes | stable across renames |
| `valid_from` | date | 0 | yes | inclusive |
| `valid_to` | date | 0 | yes | exclusive; `NA` = currently open |
| `org_unit_name` | string | 0 | yes | |
| `parent_org_unit_id` | string | 0 | no | `NA` for the root |
| `org_unit_level` | integer | 0 | no | 1 = top of hierarchy |

### 2.4 `pa_job`

Grain: one row per job code.

| column | type | tier | required | notes |
|---|---|---|---|---|
| `job_id` | string | 0 | yes | |
| `job_title` | string | 0 | yes | |
| `job_family` | string | 0 | no | |
| `job_level` | integer | 0 | yes | ordinal; used to derive promotion/demotion/lateral |

### 2.5 `pa_position` (optional — `full` conformance only)

Grain: one row per position per validity interval. Only required for organizations that manage
headcount by funded position rather than by person.

| column | type | tier | required | notes |
|---|---|---|---|---|
| `position_id` | string | 0 | yes | |
| `valid_from` | date | 0 | yes | |
| `valid_to` | date | 0 | yes | `NA` = open |
| `job_id` | string | 0 | yes | |
| `org_unit_id` | string | 0 | yes | |
| `is_filled` | logical | 0 | yes | |

## 3. Derived tables

Produced by `workforce` from `pa_event`. Defined here so independent implementations agree on
shape, not just on the packages that produce them.

### 3.1 `pa_assignment`

Grain: one row per person per uninterrupted assignment interval (SCD-2, folded from events).

| column | type | notes |
|---|---|---|
| `person_id` | string | |
| `valid_from` | date | inclusive; equals the triggering event's `event_date` |
| `valid_to` | date | exclusive; `NA` = currently active |
| `org_unit_id` | string | |
| `job_id` | string | |
| `manager_person_id` | string | |
| `fte` | double | |
| `is_on_leave` | logical | derived from `leave_start`/`leave_end` |
| `exit_type` | string | populated only on the terminal row when the interval ends in `exit` |

### 3.2 `pa_headcount_snapshot`

Grain: one row per person per period (default monthly).

| column | type | notes |
|---|---|---|
| `person_id` | string | |
| `period` | date | period start, e.g. first-of-month |
| `is_active` | logical | active as of period end, excluding those on leave per org policy flag |
| `org_unit_id`, `job_id`, `fte` | — | as of period end, joined from `pa_assignment` |

## 4. Conventions

- **Naming.** `snake_case` throughout. `_id` for keys, `_date` for `Date`, `_dt` reserved for
  future timestamp columns, `is_*` / `has_*` for logicals.
- **Dates.** Timezone-free `Date`, never `POSIXct`, unless a future `_dt` column is introduced
  for genuine sub-day events.
- **Intervals.** Half-open `[valid_from, valid_to)`. Open-ended intervals use `NA` for
  `valid_to` — never a sentinel like `9999-12-31`, which breaks comparisons and sorting.
- **FTE.** Numeric in `(0, 1]`. Multi-job persons are out of scope for v0 (each `pa_event`
  assumes one active assignment per person).
- **Currency.** Any `*_amount` column pairs with a `*_currency` column (ISO 4217). No implicit
  currency.
- **Missingness.** Use the language-native missing value (`NA` in R, `pd.NA`/`None` in Python),
  never empty string or magic numbers.

## 5. Sensitivity tiers

Every column above is tagged:

- **Tier 0 — structural/public.** IDs, dates, org/job structure. Safe to aggregate and display
  at any granularity permitted by the conformance level.
- **Tier 1 — restricted.** Pay, manager identity, regretted-attrition judgment. Requires
  aggregation/suppression before external or broad-audience display.
- **Tier 2 — protected class.** Gender, ethnicity, age (via `birth_date`), disability status.
  Requires the strictest suppression defaults and is the join key for future `pa.fairness`
  analysis — never for headcount reporting directly.

Tiers are metadata now (encoded in each JSON Schema as an `x-padm-tier` annotation); a future
`pa.privacy` package reads them to apply aggregation/suppression thresholds automatically. No
enforcement in v0 — the point of tagging early is that the hook exists before the reporting
layer is built, not that it's enforced yet.

## 6. Conformance levels

A dataset or package declares the level it targets:

- **`core`** — `pa_person` (id only) + `pa_event` + `pa_org_unit`, required columns only. Enough
  for headcount and attrition.
- **`extended`** — adds `pa_job`, pay fields, and optional `pa_person`/`pa_event` columns.
  Enough for movement, tenure-by-job, and compensation-adjacent reporting.
- **`full`** — adds `pa_position`. Required for position-managed organizations.

`padm_validate(data, level = "core")` (in `workforce`) checks a set of tables against the level's
required columns, types, and the controlled vocabularies, and reports which level the data
actually satisfies.

## 7. The turnover denominator (open question, resolved for v0)

The sharpest evidence that a shared standard is needed: every organization computes "turnover
rate" differently, using one of at least three denominators over the same numerator (exits in
period):

- **Beginning headcount** — simplest, but overstates rate in fast-growing orgs (denominator is
  stale before the period even starts).
- **Average headcount** — `(beginning + ending) / 2`. Common in HR reporting; not exposure-
  correct for uneven hiring/exit timing within the period.
- **Exposure time (person-months/person-days)** — sum of active time each person contributed
  during the period. Exposure-correct regardless of when in the period people joined or left.

**v0 makes `exposure` the canonical `padm` definition** — it is the only one that is
mathematically consistent with the event-sourced spine (§1), since exposure time is a direct sum
over `pa_assignment` intervals, not an approximation from two snapshots. `attr_rate()` defaults
to `definition = "exposure"` and requires the other two be named explicitly when used, specifically
so a report is never ambiguous about which number it's showing.

## 8. Non-goals for v0

Multi-job/concurrent-assignment persons; intra-day event ordering; compensation total-reward
detail beyond base pay; performance ratings; survey/engagement data (`pa.survey`, later); any
enforcement mechanism for §5 tiers (`pa.privacy`, later).

## 9. Versioning

`padm` follows semver against this spec, not against any single implementation. A breaking
change to a required column, key, or conformance level is a major version. Additive optional
columns are minor. `workforce` and `attrition` each declare the `padm` version range they
support.
