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

<!-- RTK_TOKEN_SAVER_START -->
# RTK Token Saver Rule (claude)

## RTK (Rust Token Killer) Optimization Rule
Prefix every shell/terminal execution command with `rtk`:
- `rtk git status`, `rtk git diff`, `rtk git log -n 5`
- `rtk npm test`, `rtk npm run build`, `rtk pnpm test`, `rtk yarn test`
- `rtk cargo check`, `rtk cargo test`, `rtk cargo build`
- `rtk pytest`, `rtk vitest`
- `rtk ls src/`, `rtk tree -L 2`, `rtk rg "pattern"`

Keep the prefix inside chains: `rtk git add . && rtk git commit -m "msg"`.
Commands RTK has no filter for run as-is, so the prefix is always safe.

### Output & Token Optimization
Command output is condensed to save 60-90% LLM context window tokens while preserving every critical signal, error, and exit code.
- `rtk gain` / `rtk gain --history` - View token savings scoreboard.
- `rtk proxy <cmd>` - Run a command unfiltered if raw output is strictly needed.
- `RTK_DISABLED=1 <cmd>` - Skip RTK for one command.

## 3-Tier Hybrid Web Research & Scraping Policy (Upstream: fastcrw/crw & lightpanda-io/browser)
When your IDE agent receives a task requiring web research or extraction, it follows this strict 3-tier routing logic:

1. **Discovery (Tier 1 - Default Search)**:
   - The agent uses its built-in search tool (`search_web` / native search) to find target URLs or documentation links.
2. **Fast Extraction (Tier 2 - fastCRW)**:
   - The agent attempts to fetch the URL using fastCRW (`crw scrape <url>`, `crw_scrape`, or `http://127.0.0.1:3000`).
   - If the page is server-rendered (like a blog, GitHub README, or docs site), fastCRW instantly grabs clean Markdown/text, saving 70-90% context tokens without JS engine overhead.
3. **Deep Dynamic Rendering (Tier 3 - Lightpanda Local via MCP)**:
   - If fastCRW returns empty content, a rendering error, or hits a client-side JavaScript wall (e.g., a React/Vue SPA app or login-gated dashboard), the agent automatically falls back to Lightpanda Local via MCP (`lightpanda mcp`).
   - Lightpanda executes the JS via V8 and feeds a clean Accessibility Tree or Markdown back into the IDE context window using ~10x less memory than headless Chrome.


## Mandatory Semantic Knowledge Graph First Policy (Token Saver Enforcement)
Autonomous AI agents in ANY IDE MUST ALWAYS query the pre-indexed semantic knowledge graphs to provide answers BEFORE falling back to raw file reads that waste prompt tokens:

### 1. Code-Based Files -> CodeGraphContext (Upstream: CodeGraphContext/CodeGraphContext)
- **Code Query Engine:** For all code architecture, symbol definitions, function signatures, call hierarchies (callers/callees), class inheritance, and module dependencies, AI agents MUST query the CodeGraphContext index (/codegraph-query, `cgc query`, `cgc find`, or CodeGraphContext MCP tools) FIRST.
- **Zero-Waste Fallback:** NEVER dump or read entire source code files or directory trees into LLM prompt context when answering code questions. Only fall back to localized file reads (and then only targeted slices) if the knowledge graph query does not provide sufficient detail.
- **Live Synchronization:** The project code graph is continuously kept updated via background incremental sync / `cgc watch` / on-save triggers.

### 2. Non-Code Files -> JevGraph (Upstream: chenmingtang830/jevgraph)
- **Document Query Engine ONLY:** JevGraph is strictly designated for non-code files (documentation, Markdown specs, PRDs, PDFs, Word docs `.docx`, slides `.pptx`, text `.txt`).
- **Bounded Evidence:** When ingesting large specs, PRDs, PDFs, or architectural documentation, build or query bounded evidence-backed knowledge graphs (/jevgraph-build, /jevgraph-query) with character-level page maps instead of loading raw long documents into prompt context.
- **Strict Separation:** NEVER use JevGraph for source code AST indexing; code files are strictly handled by CodeGraphContext.


## Headroom Context Compression (Upstream: headroomlabs-ai/headroom)
- Utilize Headroom context compression and Compress-Cache-Retrieve (CCR) for heavy JSON structures, file reads, and tool payloads to minimize prompt tokens.


## Anti-Slop Filter & Quality Rules (Upstream: miqdadbadjuber/anti-slop)
Follow Anti-Slop rules to prevent generic AI slop in generated UI, copy, and code comments (Mode: DURING):
- **Filter, Not Style Guide:** Run purpose tests before aesthetic choices (reject ungrounded neon glows, fake metrics, generic sparkle badges).
- **Liveliness & Grounding:** Rely on `DESIGN.md` or explicit brief for design soul; enforce WCAG AA human accessibility.
- **Dedicated Skills:** Read `skills/antislop/SKILL.md` (core), `skills/antislop-ui/SKILL.md`, `skills/antislop-copywriting/SKILL.md`, `skills/antislop-human/SKILL.md`, `skills/antislop-layoutmobile/SKILL.md`, `skills/antislop-code/SKILL.md` when performing relevant tasks.


## Output & Generation Token Saver Rule (Ponytail Mode: FULL)
- **YAGNI & Shortest Diff:** Only write code that must exist. Reach for standard library before custom code or new dependencies. Shortest working diff wins.
- **Terse Responses:** Code first. At most 3 short lines of explanation: what was skipped, when to add it. No essays, no unsolicited design tours, no feature walkthroughs.

## Terse Agent Directives
- Eliminate pleasantries, greetings, and conversational filler. Provide direct answers and actionable code.
- Avoid reprinting unchanged code blocks. Use targeted search/replace blocks or concise snippets.

## Context Optimization (Compact Diffs & Outlines)
- Inspect git changes using compact single-line diffs: `rtk git diff -U1` instead of wide multi-line context.
- When exploring codebases, inspect function signatures / AST outlines (/rtk-outline) before reading entire files into context.

## ECC Context Management & Compaction Protocol (Upstream: affaan-m/ECC)
Autonomous AI agents MUST actively manage conversation context window load to prevent token bloat and degraded reasoning:
1. **Strategic Compaction at Milestones:** At major phase completions or after 50+ tool calls, invoke strategic compaction (/strategic-compact) to summarize completed steps, pruned raw outputs, and focus active memory strictly on pending requirements.
2. **Context Keeper (`ck`) Snapshots:** Before major context purges, architectural refactors, or switching tasks, persist durable checkpoint files (`.agents/ck/context.json` and `.agents/ck/CONTEXT.md` or invoke /ck:save) so state is never lost across conversation boundaries.
3. **Anti-Loop Council & Agent Evaluation:** If stuck in repeated failed edits, build verification errors, or circular debug loops (>3 failed attempts), invoke /council or /agent-evaluator to obtain root-cause guidance and stop wasting tokens on trial-and-error repetition.

## Upstream Engine Integration & Latency Guardrails Standards
Whenever a new upstream engine or external tool (e.g. `fastcrw/crw`, `CodeGraphContext`, `JevGraph`) is introduced or updated:
1. **Holistic Dashboard Integration (8 Surfaces Required)**:
   - Header action toggle button (`Turn <Tool> ON / OFF`)
   - Setup alert banner (missing chips + AI install prompt generator)
   - Dedicated dashboard section & Quick Action triggers
   - Multi-channel savings breakdown navigation tabs & distribution weights
   - System Health diagnostics row with status, AI install prompt, sync, and uninstall actions
   - Upstream versions dropdown listing
   - Upstream Sync Picker (`showSyncPicker`) and Uninstall Picker (`showUninstallPicker`)
   - Footer upstream reference links
2. **Zero-Noise Latency Benchmarks**: "Test Upstream Latencies" must selectively ping and display only **installed** upstream components, silently omitting/ignoring uninstalled tools so users never see failed pings or clutter for optional tools.
3. **Footer Version Number Invariant**: The current plugin release version must always be presented beside "Token Saver" in front of "• GitHub".

<!-- RTK_TOKEN_SAVER_END -->
