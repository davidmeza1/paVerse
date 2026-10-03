# To do

Derived from [peopleverse-strategy-plan.md](peopleverse-strategy-plan.md) §12. These are
**sequenced, not parallel** — each step assumes the previous one is real. Don't jump ahead to
governance/infra items (name, charter, council, website) until step 4 is actually reached.

## 1. Outside feedback on the artifact
- [ ] Identify a handful of practicing people-analytics folks to review the work
- [ ] Share `spec/padm/padm-v0.md` (the RFC) for comment
- [ ] Share the rendered `demo/attrition-report.html` output
- [ ] Collect and log feedback; note anything that should change the v0 spec

## 2. Python parity for `padm`
- [ ] Write a Python reference implementation of `padm_validate()` against the existing JSON Schemas
- [ ] Verify it validates the same synthetic datasets consistently with the R implementation
- [ ] Only then start describing the project as "dual-language" anywhere public

## 3. Widen surface — only if step 1's feedback calls for it
- [ ] Re-check feedback from step 1 before starting any of the below
- [ ] If needed: a second HRIS export vendor shape for the synthetic/raw-export simulator
- [ ] If needed: `pa.connect` adapters (Workday, SuccessFactors, BambooHR shapes)
- [ ] If needed: pull forward specific Layer 2/3 packages from §6 (`movement`, `attritionmodels`, `pa.fairness`, `pa.survey`, `pareport`, `workforcetables`, `pa.shiny`, `pa.privacy`, `pa.validate`)

## 4. Governance and infrastructure — only once the above produces something worth governing
- [ ] Settle the ecosystem name (Appendix A leans **paverse**)
- [ ] Draft the charter (objective, scope, non-endorsement disclaimer)
- [ ] Recruit founding collaborators / initial council (5–9, cross-organizational)
- [ ] Stand up infrastructure: GitHub org, R-universe namespace, PyPI namespace, minimal website

---

## Open decisions (Appendix A — resolve opportunistically, not blocking)
- [ ] Ecosystem name/brand (recommended: `paverse`)
- [ ] Neutral governing home: partner body vs. independent entity
- [ ] License policy (recommended: permissive, MIT/Apache-2.0)
- [ ] R-first, Python-first, or strict parity for Phase 1
- [ ] Depth of Posit *professional* dependence (Workbench/Connect/Package Manager) vs. fully open-source-installable core
