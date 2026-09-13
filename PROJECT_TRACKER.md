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

- [x] Add dependency manifest (`renv::init()` + `renv.lock`)

#### Result / Implementation Notes
**2026-09-13** — Ran `renv::init()`, which scaffolded `renv/` (private project library + activate script), `.Rprofile`, and `renv.lock`. Most CRAN packages (`dplyr`, `sf`, `raster`, `terra`, `ggplot2`, `plotly`, etc.) were already installed globally and got linked in automatically; `MCMCpack`, `nsga2R`, and `truncnorm` were missing and were installed via `renv::install()`.

**Notable finding:** installing `Rquefts` from its documented GitHub source (`devtools::install_github("reagro/Rquefts")`, referenced in `QUEFTS-Based-Soil-Test-Calculator-Fram.r` and several debug scripts) failed — `reagro/Rquefts` returns 404; the repo appears to have moved. A GitHub search found `cropmodels/Rquefts`, but renv's downloader also failed against that host (worked fine via plain `curl`/`download.file`/`httr`, so likely an environment-specific quirk in renv's own HTTP client, not a real outage) — **the user pointed out `Rquefts` is simply on CRAN** (https://cran.r-project.org/package=Rquefts, currently v1.2-8), which installed cleanly and is a better, more reproducible source than a GitHub ref anyway. Updated `QUEFTS-Based-Soil-Test-Calculator-Fram.r`'s install fallback from `devtools::install_github("reagro/Rquefts")` to `install.packages("Rquefts")`. Also fixed an incidental casing bug in `quefts_calculation_engine.R` — it called `require(RQuefts, ...)` (capital Q) while the real/installed package and every other file use `Rquefts` (lowercase q), so that `require()` would always have silently failed to the fallback branch. Left the two Phase-2 debug scripts (`test_quefts_modes.r`, `test_rquefts_simple.r`) that print the old `install_github('reagro/Rquefts')` instructions as-is — they're inert historical artifacts, not executed logic.

Several packages (`leaflet`, `DT`, `knitr`, `rmarkdown`, `MCMCpack`, `truncnorm`, `htmlwidgets`) are declared as string vectors (e.g. `required_packages <- c("ggplot2", "plotly", "leaflet", ...)`) and loaded in a loop, rather than via literal `library(x)` calls — `renv`'s static dependency scanner (`renv::dependencies()`) doesn't detect this pattern, so an initial `renv::snapshot()` silently omitted them. Resolved by explicitly passing the full used-package list (static scan results + the dynamically-declared ones, found via `grep` for `_packages <- c(` across the repo) to `renv::snapshot(packages = ...)`. Final `renv::status()` reports a benign "installed/recorded but used=n" note for those same packages and their transitive deps (e.g. `MCMCpack`→`coda`/`mcmc`/`quantreg`) — expected given the dynamic-loading pattern, not an actual inconsistency; `renv::restore()` on this lockfile will still work correctly.

`renv.lock` and `.Rprofile` are committed; `renv/library/` (the actual installed package binaries) is excluded via the `renv/.gitignore` that `renv::init()` generates, per standard renv convention — a fresh clone runs `renv::restore()` to reproduce the environment from `renv.lock`.

- [x] Fix broken `source()` path in `test_quefts.r` (or retire the file)

#### Result / Implementation Notes
**2026-09-13** — Changed the absolute, pre-reorg path (`c:/R_Drive/.../R_Projects/QUEFTS-Based-Soil-Test-Calculator-Fram.r`) to a relative `source("QUEFTS-Based-Soil-Test-Calculator-Fram.r")`, since the target file lives in this same project directory. File retained (not retired) — it's a small, otherwise-valid smoke test.

- [x] Resolve `pareto_optimization.R` (wire in or move to experimental area)

#### Result / Implementation Notes
**2026-09-13** — Moved to `experimental/pareto_optimization.R` via `git mv` (chose "move to experimental area" over "wire in," since it depends on `nsga2R` — used nowhere else in the project — and operates only on synthetic demo data; wiring a GAEZ/land-use optimizer into the fertilizer decision-support pipeline is a larger design decision better deferred). Added a header comment marking it explicitly as an unintegrated design sketch. Full directory reorg (with `dev-history/`, `docs/`, etc.) still comes in Phase 2 — this was just enough to stop it reading as production code.

- [x] Address the unfinished stub in `user_interpretation_module.R` (line 514)

#### Result / Implementation Notes
**2026-09-13** — `extract_sensitivity_results()` previously returned hardcoded placeholder values regardless of input. Traced the real sensitivity analysis: `integrated_decision_support.R`'s `comprehensive_fertilizer_recommendation()` calls `perform_sensitivity_analysis()` (defined in `uncertainty_quantification.R`) and stores the result at `comprehensive_results$sensitivity_analysis` (fields: `sensitivity_ranking`, `most_sensitive`, `parameter_sensitivities[[param]]$relative_sensitivity`). Rewrote `extract_sensitivity_results()` to read from `analysis_results$sensitivity_analysis` when present, with a graceful fallback message when it's absent (e.g., for callers that pass a partial results object rather than the full pipeline output).

- [x] Revise `IMPLEMENTATION_SUMMARY.md` / `README_Framework_Components.md` to remove unverified "production ready" / "100% compliant" claims

#### Result / Implementation Notes
**2026-09-13** — Added a dated status note near the top of each doc pointing back to `PROJECT_EVALUATION.md` and this tracker. In `IMPLEMENTATION_SUMMARY.md`: reworded "✅ Production Ready: Complete testing and documentation" → "🔶 Manually Validated" (with pointer to Phases 1/4), reworded "Successful Integration Tests" → "Manual Validation Checks" (clarifying these were `cat()`-narrated manual scripts, not an automated suite), reworded the "Deployment Ready Features" section header and body to "Design Intent for Deployment (Not Yet Built)", and softened "ready for deployment" / "production-ready R code" language throughout. In `README_Framework_Components.md`: replaced the unsubstantiated "Framework Compliance Score: 100%" with "Framework Compliance (Self-Reported Inventory)" and added a note that `output_generation_module.R`/`user_interpretation_module.R` aren't yet wired into the core orchestration function (Phase 3). Kept all original technical content intact — only the maturity/status claims were corrected, not the descriptions of what was built.

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
