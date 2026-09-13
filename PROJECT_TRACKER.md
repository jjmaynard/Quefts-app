# Quefts-app: Project Tracker

**Source document:** [`PROJECT_EVALUATION.md`](./PROJECT_EVALUATION.md) (§7 Recommendations, §8 Next Steps)
**Last updated:** 2026-09-13

## How to use this document

Check a box when its task is complete, then fill in the **Result / Implementation Notes** entry directly beneath it — what was actually done, any decisions made, and any deviation from the original plan — before moving to the next task. Leave notes dated so this stays a legible execution log over time.

---

## Phase 0 — Version Control

- [x] Initialize git repo, commit as-is, push to GitHub remote

#### Result / Implementation Notes
**2026-09-13** — Ran `git init`, staged and committed all 42 existing files in a single root commit (`eedd57a`) preserving the full unpruned development history, then added remote `origin` (`https://github.com/jjmaynard/Quefts-app.git`), renamed the branch to `main`, and pushed. Repo is live at https://github.com/jjmaynard/Quefts-app.

---

## Phase 1 — Repository Hygiene

*(§7 items 2–3, 6, 7, 9, 10 — independent, low-risk, do first)*

- [ ] Add dependency manifest (`renv::init()` + `renv.lock`)

#### Result / Implementation Notes
_Not started._

- [ ] Fix broken `source()` path in `test_quefts.r` (or retire the file)

#### Result / Implementation Notes
_Not started._

- [ ] Resolve `pareto_optimization.R` (wire in or move to experimental area)

#### Result / Implementation Notes
_Not started._

- [ ] Address the unfinished stub in `user_interpretation_module.R` (line 514)

#### Result / Implementation Notes
_Not started._

- [ ] Revise `IMPLEMENTATION_SUMMARY.md` / `README_Framework_Components.md` to remove unverified "production ready" / "100% compliant" claims

#### Result / Implementation Notes
_Not started._

---

## Phase 2 — Directory Reorganization

*(§8.1 — do after Phase 1 so there's little left to fix mid-move)*

- [ ] Reorganize flat file layout into `R/core/`, `R/modules/`, `R/decision_support/`, `tests/`, `demo/`, `dev-history/`, `docs/`, `data/` as a single tracked `git mv` commit

#### Result / Implementation Notes
_Not started._

---

## Phase 3 — Wire the Full Pipeline

*(§7 item 5 / §6.8 — core-logic fix, do before building tests/API against it)*

- [ ] Wire `output_generation_module.R` and `user_interpretation_module.R` into `integrated_decision_support.R`'s `comprehensive_fertilizer_recommendation()` so it returns a complete, report-ready result

#### Result / Implementation Notes
_Not started._

---

## Phase 4 — Automated Testing

*(§7 item 6 / §8.3)*

- [ ] Convert manual `cat()`-driven validation scripts into a `testthat` suite under `tests/testthat/`, using existing hardcoded inputs as fixtures

#### Result / Implementation Notes
_Not started._

---

## Phase 5 — Data Assets

*(§8.4)*

- [ ] Add sample/fixture soil datasets under `data/`; refactor hardcoded inline soil values in demo/test scripts to load from these fixtures

#### Result / Implementation Notes
_Not started._

---

## Phase 6 — API Layer

*(§8.5 Phase A)*

- [ ] Wrap `comprehensive_fertilizer_recommendation()` in a Plumber API (`plumber.R`) with `POST /recommendation` and `GET /crops` endpoints

#### Result / Implementation Notes
_Not started._

---

## Phase 7 — Next.js Frontend Skeleton

*(§8.5 Phase B)*

- [ ] Scaffold Next.js app; build calculator form + results view against the Plumber API

#### Result / Implementation Notes
_Not started._

---

## Phase 8 — Full Decision-Support Workflow

*(§8.5 Phase C)*

- [ ] Add visualization (yield-response curves, uncertainty bands, map) and SSR shareable result pages (`/results/[id]`)

#### Result / Implementation Notes
_Not started._

---

## Phase 9 — Deployment

*(§8.5 Phase D)*

- [ ] Containerize Plumber API; deploy Next.js app to a Node-capable host

#### Result / Implementation Notes
_Not started._
