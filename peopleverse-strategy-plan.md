# Building a "pharmaverse for People Analytics"
### A strategy and development plan for a curated, community-governed open-source ecosystem

*Draft v0.2 — August 2026 · Working name: **peopleverse** (placeholder; **paverse** recommended, see Appendix A)*

**Status:** `padm` v0 (spec + schemas), `pa.synthetic`, `workforce`, and `attrition` are built and
passing, and a working raw-export → attrition-report demo runs end to end on synthetic data — see
[spec/padm/](spec/padm/), [pkg/](pkg/), and [demo/](demo/). This is a solo proof, not yet a
community project. §12 has been rewritten to reflect what's actually been built and what a
sequenced path forward looks like from here.

---

## 1. Executive summary

Pharmaverse succeeded by turning a fragmented, siloed, duplicative problem space (clinical reporting in pharma) into a **curated network of interoperable open-source packages** backed by a light-touch charter, a contribution model, shared data standards, and neutral hosting. People analytics sits in an almost identical position today: every company rebuilds the same headcount, attrition, and reporting logic privately, in incompatible ways, on incompatible data models.

This plan proposes an equivalent ecosystem for people analytics, built primarily on the **Posit open-source and professional stack** (R and Python), governed by a community council, and delivered through a curated package library, a public website, and reproducible reference workflows. We start narrow — **data standards, core/attrition metrics, and reproducible reporting** — and grow the network from there.

The single biggest difference from pharmaverse, and the one that shapes every design decision below, is **data sensitivity**: HR data is personal, regulated (GDPR, EEOC, pay-transparency laws), and rarely "post-competitive" in the way anonymized clinical trial standards are. The ecosystem therefore leads with privacy-preserving design, synthetic data, and governance rather than treating them as afterthoughts.

---

## 2. Vision

> A connected network of practitioners and organizations collaboratively developing curated, interoperable open-source R and Python packages for people analytics — so teams stop rebuilding the same headcount, attrition, and reporting logic in silos, and instead share validated, reproducible building blocks.

**What "good" looks like in 3 years:**

- A practitioner can install a handful of interoperable packages and go from raw HRIS export to a validated attrition model and a stakeholder-ready report in a reproducible pipeline.
- A common, documented **people-analytics data model** exists that packages read and write, the way pharmaverse packages share CDISC SDTM/ADaM.
- New contributors have a clear, low-friction path from "I built a useful function" to "it's a recommended package in the ecosystem."
- Organizations trust the ecosystem enough to adopt it internally because of transparent governance, validation tooling, and privacy-first defaults.

### The pharmaverse analogy (and where it breaks)

| Pharmaverse element | People-analytics equivalent | Notes / divergence |
|---|---|---|
| Post-competitive clinical reporting | Post-competitive HR reporting (headcount, attrition, standard metrics) | Weaker "post-competitive" consensus; must be built deliberately |
| CDISC SDTM / ADaM data standards | A shared people-analytics data model (proposed) | **Does not exist yet — must be created.** Biggest foundational gap |
| `admiral` (derived datasets) | Attrition / movement / tenure derivation package | Core early package |
| `teal` / `rtables` (reporting) | Shiny/Quarto reporting + workforce table packages | Leverage Posit stack directly |
| Synthetic data (`pharmaversesdtm`) | Synthetic HR datasets | **Essential** — enables open dev without exposing PII |
| Validation working group (`riskmetric`, `valtools`) | Validation + fairness/bias assessment tooling | Add algorithmic-fairness dimension |
| R-universe hosting | R-universe + PyPI + Posit Package Manager | Dual-language from day one |
| Charter + council governance | Charter + council governance | Adopt closely |
| PHUSE industry backing | An anchor community body (see §8) | Need an equivalent neutral home |

---

## 3. Landscape and rationale

**What already exists (point solutions, not an ecosystem):**

- `hR` (CRAN) — HR-specific data-engineering helpers.
- `vivainsights` / `wpa` (Microsoft) — analysis of Viva Insights / Workplace Analytics data; ~100+ curated functions, ONA, clustering, churn.
- General-purpose modeling stacks used ad hoc: `tidymodels`, `survival`, `lme4`, `igraph`/`tidygraph` for ONA.
- Strong learning resources — *The Fundamentals of People Analytics (R)*, *R for HR*, the Big Book of R people-analytics chapter — but no coordinating package layer.

**The gap:** these are isolated, mostly single-vendor or single-author, and share no common data model or interoperability contract. Nobody plays the curating/standard-setting role pharmaverse plays. That coordinating layer — standards + interoperability + governance + curation — is the opportunity.

**Why now:** mature Posit tooling for reproducibility and deployment; rising regulatory pressure (pay transparency, AI-in-HR audit requirements) that rewards transparent, auditable methods; and a large, R/Python-literate people-analytics community actively looking for shared standards.

**Why not adopt an existing HR data standard?** [HR Open Standards](https://www.hropenstandards.org/) (the modern continuation of the earlier HR-XML Consortium work) already defines XML/JSON payloads for candidate, job, and worker data — but it's aimed at *system-to-system integration* (ATS ↔ HRIS ↔ payroll), not analytics. It solves a different problem than `padm`: HROS is a wire format for point-in-time interchange, with no native concept of an immutable event stream, a `[valid_from, valid_to)` assignment interval, or a controlled attrition-event taxonomy — the things that make derived views (headcount, tenure, attrition) reconstructable and reconcilable rather than approximated. Profiling HROS would import its deeply-nested, transaction-oriented shape without buying interoperability, since no `padm` consumer needs HROS wire compatibility in Phase 1. `padm` v0 is therefore greenfield: a tidy, analysis-first schema, expressed as language-neutral JSON Schema so an adapter *from* HROS or a specific HRIS export shape is possible later without having constrained v0's design today (see §6, "padm design decisions").

---

## 4. Design principles

1. **Privacy and ethics first.** Synthetic data for all examples/tests; no PII in any repo; privacy-preserving defaults (k-anonymity/aggregation thresholds); fairness and adverse-impact tooling as first-class, not bolt-on.
2. **Interoperable by contract.** Packages agree on a shared data model and column conventions so outputs of one are inputs to the next (the `admiral`→`teal` pattern).
3. **Dual-language, tidy-idiomatic.** R and Python treated as equal citizens; R packages follow tidyverse design principles, Python packages follow a documented equivalent (pandas/polars-friendly, typed).
4. **Reproducible end to end.** `renv`/`venv`, Quarto, and pipeline tooling (`targets`) so any published result can be regenerated.
5. **Curated, not centralized.** Packages can live in any org's GitHub; the ecosystem curates and cross-links rather than owning all code (pharmaverse model).
6. **Validated and documented.** Every recommended package meets minimum bars for tests, docs (pkgdown/Quarto sites), and a documented validation/risk posture.
7. **Low friction to contribute.** Clear inclusion criteria, issue templates, and a public Slack/Discourse.

---

## 5. Architecture on the Posit stack

**Development & authoring**
- **Posit Workbench** (or open-source RStudio / VS Code) as the reference IDE.
- **Quarto** for all documentation, reports, examples, and the ecosystem website.
- `renv` (R) and `venv`/`uv` (Python) for reproducible environments.

**Package build & distribution**
- **R-universe** as the CRAN-like community registry (as pharmaverse does), plus CRAN for stable releases.
- **PyPI** for Python packages; optional conda-forge later.
- **Posit Package Manager** as the recommended way for organizations to mirror/pin a validated internal snapshot.

**Modeling & pipelines**
- `tidymodels` (R) / `scikit-learn` (Python) for modeling.
- `targets` (R) / equivalent for reproducible pipelines.
- `pointblank` / `pandera` for data validation against the shared data model.

**Deployment & apps**
- **Shiny** (R and Python) for interactive apps; **Quarto dashboards** for lighter reporting.
- **Posit Connect** as the recommended publishing/hosting layer for internal deployment.
- `vetiver` + `plumber`/`FastAPI` for deploying and versioning any predictive models (e.g., attrition risk) with monitoring.

**The reference pipeline the ecosystem makes easy:**

```
Raw HRIS export
   → [ingest/standardize pkg] → shared People-Analytics Data Model
   → [derivation pkg: tenure, movement, attrition flags]
   → [metrics pkg: headcount, turnover, retention curves]
   → [modeling: survival / tidymodels attrition risk]
   → [fairness/validation checks]
   → [reporting pkg: Quarto/Shiny] → Posit Connect
```

---

## 6. Proposed package portfolio

Organized in four layers. Names are placeholders. This was originally a twelve-package v0.1
wishlist with six items flagged "Phase 1 priority." **v0.2 trims Phase 1 down to the four items
actually built in this proof** (marked ✅); everything else here is v0.1's longer-term portfolio,
kept for context but explicitly not started — see §12 for why the rest waits.

### Layer 0 — Foundation & standards
- **`padm` — People-Analytics Data Model.** ✅ v0 shipped ([spec/padm/](spec/padm/)): event-sourced
  spine, JSON Schema per table, controlled event vocabulary, sensitivity tiers, conformance
  levels. See "padm design decisions" below.
- **`pa.synthetic` — synthetic HR datasets.** ✅ shipped ([pkg/pa.synthetic/](pkg/pa.synthetic/)):
  seeded generators (org, jobs, hiring cohort, hazard-based event stream), a deliberately messy
  raw-export simulator, and a documented adverse-impact signal for future fairness tooling.
- `pa.connect` — connectors/adapters for common HRIS exports (Workday, SuccessFactors, BambooHR
  CSV shapes) → `padm`. *Not started.*

### Layer 1 — Core metrics & derivations
- **`workforce` — derivation engine.** ✅ shipped ([pkg/workforce/](pkg/workforce/)): assignments,
  headcount snapshots, tenure, `padm_validate()`, and the `opening + hires − exits == closing`
  reconciliation check (the `admiral` analogue).
- **`attrition` — turnover & retention metrics.** ✅ shipped ([pkg/attrition/](pkg/attrition/)):
  turnover rate under three explicit denominator definitions, rolling rates, Kaplan-Meier
  retention curves, cohort tables.
- `movement` — internal mobility, promotion velocity, org network flows. *Not started.*

### Layer 2 — Modeling & assessment *(not started; deferred past the proof phase)*
- `attritionmodels` — opinionated survival + `tidymodels`/`scikit-learn` recipes for turnover
  risk, with `vetiver` deployment templates.
- `pa.fairness` — adverse-impact (4/5ths rule), representation, and pay-equity/statistical-
  fairness testing. (`pa.synthetic`'s documented adverse-impact signal exists specifically to give
  this package something real to detect, whenever it's built.)
- `pa.survey` — survey scale construction, reliability, driver analysis (eNPS/engagement).

### Layer 3 — Reporting & delivery *(not started as packages; `demo/` is a one-off proof, not a package)*
- `pareport` — reproducible reporting templates (Quarto) for standard HR packs: headcount,
  attrition, DEI representation.
- `workforcetables` — standardized workforce tables (headcount by dimension, movement tables)
  built on `gt`/`great_tables`.
- `pa.shiny` — reusable Shiny modules/components (filters, org-hierarchy pickers, privacy-
  threshold guards) for building dashboards on Posit Connect.

### Cross-cutting utilities *(not started)*
- `pa.privacy` — aggregation thresholds, k-anonymity/suppression helpers, PII scrubbing. `padm`'s
  sensitivity tiers (see below) are the hook this package will eventually read.
- `pa.validate` — package validation/risk metadata (a `riskmetric`/`valtools` analogue) tailored
  to HR.

### padm design decisions (v0)

`spec/padm/padm-v0.md` is the ratified-for-now RFC. The decisions worth surfacing here because
they shape every package built on top of it:

- **Event-sourced spine, derived snapshots.** `pa_event` is the only source of truth;
  `pa_assignment` and `pa_headcount_snapshot` are always derived, never stored independently. This
  is what makes `opening + hires − exits == closing` a checkable invariant
  (`workforce::wf_reconcile()`) instead of an approximation — verified with zero mismatches across
  30+ independently-seeded synthetic datasets plus the large cached demo dataset.
- **Conformance levels** (`core` / `extended` / `full`) let a dataset or package declare the
  minimum shape it needs, checked by `padm_validate()`, without forcing every organization to
  supply position-management data on day one.
- **Sensitivity tiers** (0 structural, 1 restricted, 2 protected-class) are tagged in every JSON
  Schema now, with no enforcement yet — the hook for a future `pa.privacy` package exists before
  the reporting layer does, rather than being retrofitted later.
- **Turnover denominator: `exposure` is canonical.** Beginning headcount, average headcount, and
  exposure-time produce three different numbers on identical data — `attr_rate()`'s three-
  definition comparison in `demo/attrition-report.qmd` (§6 of the report) is the concrete proof.
  `padm` mandates `exposure` as the default specifically because it's the only definition that's
  mathematically consistent with an event-sourced spine.
- **Greenfield over profiling an existing standard** — see §3 for why HR Open Standards / hrXML
  wasn't adopted as a starting point.

---

## 7. Governance and the charter

Adopt the pharmaverse model closely, adapted for HR sensitivities.

**Charter (to be drafted first):** states the high-level objective (curated, interoperable, privacy-first open-source people analytics), scope (what's in/out), and non-endorsement disclaimer (listing ≠ warranty; users assess fitness and license themselves).

**Council (5–9 people):** cross-organizational, adjudicates contentious inclusion/removal decisions and stewards the charter. Seek diversity across employers, geographies, and R/Python. Rotate seats.

**Package inclusion criteria (public checklist):**
- Conforms to the `padm` data model (or is a foundational/standards package).
- Open-source license, public repo, passing CI.
- Tests + documented coverage; a pkgdown/Quarto documentation site.
- Uses synthetic data only in examples/tests (no PII).
- Passes a privacy/ethics review (aggregation defaults, no re-identification risk in examples).
- Named maintainer and a stated support/validation posture.

**Decision process (pharmaverse-style):** anyone opens a "new package request" issue → community comment window on Slack/Discourse → website team actions if uncontested → council adjudicates if contested. Same lightweight path for removals.

---

## 8. Infrastructure and community

**Website** (Quarto or Hugo, like pharmaverse.org): package library with searchable tags (e.g., `standards`, `attrition`, `reporting`, `fairness`, `python`), charter, contribute, support, examples, blog. Static, cheap to host (GitHub Pages / Netlify).

**Package hosting:** R-universe org for R, PyPI for Python, docs auto-built via GitHub Actions. A "get packages" page mirroring pharmaverse's R-universe instructions.

**Reference examples:** an `examples` repo showing the full raw-export→report pipeline on synthetic data — the single most persuasive artifact for adoption.

**Community:** Slack or Discourse; a LinkedIn presence (the PA community lives there); a recurring community call; talks at people-analytics and R/Python conferences.

**Anchor/neutral home:** pharmaverse leans on PHUSE. Identify an equivalent — options include partnering with an existing PA community/association, a vendor-neutral foundation, or standing up a lightweight independent entity. Neutrality matters for multi-employer trust.

---

## 9. Phased roadmap

**Phase 0 — Foundations (Months 0–3)**
- Draft and publish the charter; recruit an initial council/steering group.
- Register the GitHub org, R-universe, PyPI namespace; stand up a minimal website.
- Ship `pa.synthetic` (synthetic data) and a first `padm` draft spec (RFC for comment).
- Publish one end-to-end example notebook on synthetic data to demonstrate intent.
- *Milestone: charter live, synthetic data + data-model RFC public, first contributors engaged.*

**Phase 1 — Core value (Months 3–9)** *(the chosen focus areas)*
- Ratify `padm` v1; ship reference implementations in R and Python.
- Ship `workforce` (derivations) and `attrition` (metrics) with full tests/docs.
- Ship `pareport` + `workforcetables` reporting templates; deploy the reference report to Posit Connect.
- Ship `pa.privacy` defaults used across all packages.
- *Milestone: a practitioner can go raw export → attrition report reproducibly using only ecosystem packages.*

**Phase 2 — Modeling, fairness, adoption (Months 9–18)**
- Ship `attritionmodels` (+ `vetiver` deployment) and `pa.fairness`.
- Add `pa.connect` adapters for 2–3 major HRIS export shapes.
- Publish `pa.validate` and a validation/risk posture per package.
- Formalize inclusion process; onboard first externally-authored packages.
- *Milestone: multiple organizations piloting; first third-party package admitted.*

**Phase 3 — Network effects (Months 18–36)**
- Broaden portfolio (survey, mobility, ONA, comp) via community contributions.
- Mature governance (elections, working groups: standards, validation, privacy).
- Conference presence, published case studies, a stable release cadence.
- *Milestone: self-sustaining, multi-employer contributor base.*

---

## 10. Risks and mitigations

| Risk | Why it matters here | Mitigation |
|---|---|---|
| **Data privacy / PII exposure** | HR data is personal and regulated | Synthetic-data-only policy; `pa.privacy` defaults; privacy review in inclusion criteria |
| **Weak "post-competitive" consensus** | Firms may see PA methods as proprietary edge | Lead with clearly non-differentiating primitives (headcount, standard turnover defs); let firms keep secret sauce private |
| **No shared standard exists yet** | Interop is impossible without one | Treat `padm` as the keystone deliverable; run it as an open RFC to build buy-in |
| **Regulatory/fairness liability** | AI-in-HR is increasingly audited | `pa.fairness` + documentation; position transparency as a compliance asset |
| **Single-vendor capture / neutrality** | Trust requires vendor neutrality | Cross-org council; neutral home; open governance |
| **Dual-language fragmentation** | R and Python communities diverge | Shared spec (`padm`) as the contract both sides implement; parity requirement |
| **Sustainability / maintainer burnout** | OSS commons problem | Council + working groups; corporate sponsorship of maintainer time; clear contribution ladder |

---

## 11. Success metrics

- **Adoption:** package installs/downloads (R-universe, PyPI, CRAN); GitHub stars/forks; organizations publicly using it.
- **Ecosystem health:** number of recommended packages; number of distinct contributing orgs; external (non-founder) packages admitted.
- **Interoperability:** % of packages conforming to `padm`; end-to-end examples that run green in CI.
- **Community:** Slack/Discourse members; community-call attendance; conference talks.
- **Trust:** packages with a documented validation posture; privacy reviews completed.

---

## 12. Status and next steps

v0.1 listed six unsequenced "first 30 days" items, several of which (charter, infrastructure,
founding collaborators) assumed a community before any artifact existed to organize one around.
Pharmaverse had `admiral` working before it had a council; this plan now follows the same order.

**What's built (this proof, as of August 2026):** `padm` v0 (spec + JSON schemas + event
vocabulary), `pa.synthetic`, `workforce`, and `attrition` — all passing `devtools::check()` clean
(0 errors/warnings/notes) — plus `demo/attrition-report.qmd`, a working raw-export → standardize →
validate → derive → reconcile → attrition-report pipeline on synthetic data that renders to a
self-contained HTML report. This was built solo and has not yet been shared for outside feedback.

**Sequenced next steps** — deliberately not parallel; each assumes the previous one is real:

1. **Get outside feedback on the artifact, not the idea.** Share `spec/padm/padm-v0.md` and the
   rendered demo report with a handful of practicing people-analytics folks. The spec is versioned
   as an RFC specifically so this feedback can still change it cheaply.
2. **Python parity for `padm`.** The schemas are already language-neutral JSON Schema; write a
   Python reference implementation of at least `padm_validate()` against the same schemas as a
   concrete parity check, before claiming "dual-language" anywhere public.
3. **Widen the synthetic-data and package surface only if step 1's feedback calls for it** — e.g.
   a second HRIS export vendor shape, `pa.connect` adapters, or the Layer 2/3 packages in §6 —
   rather than building ahead of demonstrated need.
4. **Only once the above produces something worth governing:** settle the ecosystem name
   (Appendix A), draft the charter, recruit founding collaborators, and stand up infrastructure
   (GitHub org, R-universe, PyPI namespace, website).

Name, charter, council, neutral home, website, and R-universe/PyPI registration (§7, §8) are
deliberately **not** near-term work — they describe what governance looks like once step 4 above
is reached, not what to do next.

---

## Appendix A — Open decisions

- **Ecosystem name and brand.** Recommend settling on **`paverse`** — it matches this repo's
  directory name, keeps the `pa.`-prefix convention the packages themselves already use, and
  costs nothing to change since nothing has been published externally yet. Still open, not yet
  acted on.
- Neutral governing home (partner body vs. independent entity).
- License policy (recommend permissive: MIT/Apache-2.0 for broad adoption).
- R-first, Python-first, or strict parity for Phase 1.
- Depth of Posit *professional* dependence (Workbench/Connect/Package Manager) vs. keeping the core fully open-source-installable.

## Appendix B — Reference models to study

- pharmaverse.org — charter, curation model, R-universe hosting, inclusion process.
- tidyverse / tidymodels — design principles and package cohesion.
- CDISC (SDTM/ADaM) — how a data standard enables an ecosystem.
- ROpenSci — peer-review model for package quality (a possible inclusion-review template).
