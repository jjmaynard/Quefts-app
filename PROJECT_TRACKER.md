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

- [x] Reorganize flat file layout into `R/core/`, `R/modules/`, `R/decision_support/`, `tests/`, `demo/`, `dev-history/`, `docs/`, `data/` as a single tracked `git mv` commit

#### Result / Implementation Notes
**2026-09-13** — Reorganized 42 files via `git mv` following the §8.1 layout, categorized per the file-by-file catalog in `PROJECT_EVALUATION.md` §4:

- `R/core/` — `QUEFTS-Based-Soil-Test-Calculator-Fram.r`, `quefts_calculation_engine.R`
- `R/modules/` — `uncertainty_quantification.R`, `bayesian_updating_module.R`, `spatial_data_integration.R`, `output_generation_module.R`, `user_interpretation_module.R`
- `R/decision_support/` — `integrated_decision_support.R`
- `demo/` — `comprehensive_framework_demo.R`, `demo_integrated_system.R` (the two 🔵 "Demo"-status files)
- `tests/` — the six 🔵 "Validation"-status files (`test_integration.R`, `test_quefts_engine.R`, `validate_uncertainty_framework.R`, `simple_validation.R`, `quick_validation_test.R`, `simple_validation_test.R`) — these stay as manual scripts until Phase 4 replaces them with a real `testthat` suite
- `dev-history/` — all 21 🟡/🔴 Phase-2-debug and Phase-3-confirmation scripts (the RQuefts-integration debugging cluster, plus `test_quefts.r`)
- `docs/` — the four framework `.md` docs + `Rquefts.pdf`
- Root — `PROJECT_EVALUATION.md`, `PROJECT_TRACKER.md`, `renv.lock`, `.Rprofile`, `renv/`, `experimental/` (from Phase 1) stay at the top level as project-meta/infrastructure, not part of the original §8.1 doc/code split
- `data/` — not created yet; deferred to Phase 5 (no fixture datasets exist to put in it yet)

**Path-breakage fix (the real work of this phase):** every `source()` and `file.exists()` call referencing another project file broke once files moved apart into different subdirectories — 25 files needed path updates. Initially tried self-relative paths (`../R/core/...` etc.), which worked when a script was run with its own directory as the working directory — but that meant `renv` never auto-activated (`.Rprofile` only sources when R starts in the directory containing it, i.e. the project root), so dependency-auto-install fragility (already flagged in Phase 1) resurfaced. Switched instead to **project-root-relative paths everywhere** (e.g. `source("R/core/quefts_calculation_engine.R")`), on the convention that R/Rscript is always launched from the repository root. This makes `renv` activate correctly *and* resolves every nested `source()` chain regardless of which file is the entry point. Verified with:
- A full syntax check (`parse()`) across all 38 R/`.r` files — all clean.
- `Rscript tests/simple_validation.R` from repo root — loads `R/core/quefts_calculation_engine.R`, `R/modules/uncertainty_quantification.R`, `R/modules/bayesian_updating_module.R` cleanly via the renv-managed library, no install prompts.
- `Rscript tests/test_integration.R` from repo root — full chain (`R/core` → `R/modules` → `R/decision_support`) loads and runs end-to-end, producing a real fertilizer recommendation and risk analysis. The only failure was `SoilGrids API request failed with status: 500` — a live external-API issue unrelated to this reorg (already flagged in `PROJECT_EVALUATION.md` §6.3 as a pre-existing fragility: no caching/fixture data for spatial calls).

**Other finding:** `dev-history/simple_test_results.r` had a `file.exists("QUEFTS-Based-Soil-Test-Calculator-Fram.r")` check that the initial `source()`-focused sweep missed (no `source()` call on that line, just the existence check) — caught and fixed in a follow-up grep for `file.exists(`.

**Convention going forward:** run all R scripts in this project with the repository root as the working directory (e.g. `Rscript tests/simple_validation.R`, not `cd tests && Rscript simple_validation.R`). This is required both for `renv` to activate and for any script's internal `source()` calls to resolve.

- [x] Improve script and function naming: fix inconsistent/typo'd filenames (e.g. the `Fram` truncation and mixed `.r`/`.R` casing) and rename ambiguous or colliding function names (including in `dev-history/`) for clarity

#### Result / Implementation Notes
**2026-09-13** — Scope, decided with the user up front: rename files across the whole project (including `dev-history/`), but only rename *functions* that are genuinely ambiguous or colliding — not a sweeping identifier rename, given how much the pipeline's correctness already turned out to depend on exact names (Phase 3's `rmarkdown::run()`/`Rquefts::run()` masking bug and the `perform_sensitivity_analysis` collision).

**Function-name audit first, before touching anything:** grepped every top-level `<- function` definition across all `.R`/`.r` files (excluding `renv/`) for duplicates. Result: clean — the only remaining collision was the `perform_sensitivity_analysis` one already fixed in Phase 3, plus a same-named *local* helper (`extract_width`) defined twice inside two different enclosing functions in `user_interpretation_module.R`, which is fine (proper lexical scoping, no actual collision). Two functions have confusingly similar names by design rather than accident — `calculate_fertilizer_needs()` (the original framework's basic calculator) vs. `calculate_fertilizer_recommendation()` (the newer Monte Carlo engine) — genuinely different pipelines, each with ~10-20 call sites across active code and `dev-history/`, several sharing name *prefixes* with sibling functions (e.g. `calculate_fertilizer_needs_with_uncertainty`, `calculate_fertilizer_needs_enhanced`). Renaming either safely would need word-boundary-aware substitution across ~20 files for a payoff of "sounds a bit clearer" — decided the risk/reward didn't clear the bar given this session's track record of exactly this kind of rename hiding a collision bug, so left both as-is.

**File renames actually done:**
- `R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r` → `R/core/quefts_soil_test_framework.R` — fixes the truncated "Fram" (was meant to be "Framework"), and brings it in line with the snake_case + `.R` convention every other active-code file already uses. This file is `source()`-d or `file.exists()`-checked by 20 other files (all of `dev-history/`, both `demo/` scripts, `tests/test_quefts_engine.R`, and `R/decision_support/integrated_decision_support.R`) — updated every reference via a targeted `sed` pass, then verified with a full `parse()` syntax check plus live runs of `tests/test_integration.R` and a renamed `dev-history/test_quefts.R` script.
- All 21 `dev-history/*.r` files renamed to `.R` (two-step `git mv` — e.g. `git mv foo.r foo_tmp.R && git mv foo_tmp.R foo.R` — since a direct case-only rename doesn't register correctly as a rename on this case-insensitive Windows filesystem). None of these files `source()` each other, so no internal reference updates were needed beyond the framework-file rename above.

**Left alone, on purpose:** `PROJECT_EVALUATION.md` and `docs/IMPLEMENTATION_SUMMARY.md` still mention the old `...Fram.r` filename and the old `dev-history/*.r` names — both are dated, point-in-time documents (the evaluation is an explicit audit snapshot; the implementation summary already got a Phase 1 status-note correction rather than a rewrite), so per the precedent set in Phase 1, their prose wasn't retroactively edited for every later code change. `PROJECT_TRACKER.md`'s own Phase 0-2 implementation notes above also still reference the pre-rename filenames where they describe what was literally done at the time — left as an accurate historical record rather than rewritten.

**Verification:** `parse()` syntax check across all 38 R/`.r` files (all clean), `Rscript tests/test_integration.R` from repo root (full module chain still loads; the only failure is the same pre-existing live SoilGrids 500), and `Rscript dev-history/test_quefts.R` (one of the renamed files) runs to completion.

---

## Phase 3 — Wire the Full Pipeline

*(§7 item 5 / §6.8 — core-logic fix, do before building tests/API against it)*

- [x] Wire `output_generation_module.R` and `user_interpretation_module.R` into `integrated_decision_support.R`'s `comprehensive_fertilizer_recommendation()` so it returns a complete, report-ready result

#### Result / Implementation Notes
**2026-09-13** — This turned out to be substantially more involved than "add a function call": `output_generation_module.R`/`user_interpretation_module.R` were built against `quefts_calculation_engine.R`'s `calculate_fertilizer_recommendation()` output shape (`detailed_results$fertilizer_rates$N$mean/cv/confidence_50/80/95/samples`), not `uncertainty_quantification.R`'s `run_quefts_with_uncertainty()` shape that Steps 2-4 already use. Reshaping the latter into the former would have been lossy (no per-nutrient native soil supply breakdown), so **Step 6 now runs the engine natively** on the same soil/crop/target inputs instead, via a small field-name adapter (the engine wants `pH/SOC/Kex/Polsen`; `spatial_data$quefts_input` has `pH/OC/Exch_K/Olsen_P` — same properties, different names, already discovered as a separate finding below). A second adapter patches `detailed_results$soil_supply` (needed by `generate_agronomic_insights()`'s `analyze_nutrient_limitations()`) from the engine's actual `soil_supply_analysis$<N|P|K>_supply$mean` field. A third converts the existing simple `fertilizer_prices` (`N_per_kg`/`P_per_kg`/`K_per_kg`/`crop_price_per_kg`, elemental-nutrient pricing) into the flat `economic_params` shape `generate_economic_analysis()` wants (`N_price`/`P2O5_price`/`K2O_price`/`crop_price`/`application_cost`/`interest_rate`, applied-product pricing) using the same P₂O₅/K₂O conversion factors `output_generation_module.R` itself uses.

`comprehensive_fertilizer_recommendation()` now returns four new fields: `primary_recommendations`, `agronomic_insights`, `economic_analysis` (NULL if no `fertilizer_prices` supplied), and `user_reports` (a list of `expert`/`beginner`/`intermediate` text reports from `generate_progressive_disclosure()` — beginner/intermediate are skipped, with `report_generation_note` explaining why, when no `fertilizer_prices` means no economic analysis to drive their traffic-light decision). The whole Step 6 block is wrapped in one `tryCatch`, so if anything in it fails, `comprehensive_fertilizer_recommendation()` still returns everything Steps 1-5 already produced (with `report_generation_note` carrying the error) rather than breaking the function entirely.

**Three real, pre-existing bugs were found and fixed along the way** — each one either directly blocked this wiring or was newly exposed by finally getting the pipeline to run end-to-end for the first time (previous attempts always failed earlier, at live SoilGrids calls or at Step 2, before ever reaching working code downstream):

1. **Package-masking regression (introduced by this wiring, fixed within it):** `output_generation_module.R` attaches `rmarkdown`, whose exported `run()` shadows `Rquefts::run()` on the search path (attached later = higher precedence). `QUEFTS-Based-Soil-Test-Calculator-Fram.r`'s `calculate_fertilizer_needs()` calls `run()` unqualified expecting `Rquefts::run()`, so *every* Step 2/Step 6 calculation would have silently failed ("a character vector argument expected", from `rmarkdown::run()` trying to treat a QUEFTS object as a file path for an Rmd) as soon as the two new modules were sourced. Fixed by detaching `rmarkdown` right after sourcing the new modules in `integrated_decision_support.R` (nothing this file calls needs it loaded).
2. **`perform_sensitivity_analysis` name collision (pre-existing, unmasked by fix #1):** `QUEFTS-Based-Soil-Test-Calculator-Fram.r` independently defines its own `perform_sensitivity_analysis(soil_data, crop_name, target_yield_kg_ha, fertilizer_prices, base_uncertainty)` — a completely different function (uncertainty-*level* sensitivity, not per-parameter) that is **never called from anywhere in the project** — which silently overwrote `uncertainty_quantification.R`'s same-named function (per-parameter sensitivity) because it's sourced later into the same global environment. This broke Step 5 for everyone, including `bayesian_updating_module.R`'s existing call, not just mine — it just had never been reached with working data before. Fixed by renaming the orphaned, uncalled version to `perform_uncertainty_level_sensitivity_analysis`.
3. **`OC` vs `SOC` field-naming mismatch (pre-existing, fixed as part of the wiring):** `spatial_data$quefts_input` (built by `convert_to_quefts_input()`) names the organic-carbon field `OC`; `perform_sensitivity_analysis()`'s default `parameters` argument looks for `SOC`, so SOC sensitivity was silently skipped (`soil_data[["SOC"]]` → `NULL` → `next`). Fixed by passing `parameters = c("pH", "OC", "Olsen_P", "Exch_K")` explicitly at the Step 5 call site to match the field names actually present.

**Also fixed in passing:** `QUEFTS-Based-Soil-Test-Calculator-Fram.r` called `print(help(quefts_soil))` at source-time (inside its own diagnostic block, which runs unconditionally every time the file is sourced) — this opens a browser tab via R's httpd help server on *every* `source()` of this file, which is disruptive for anything other than interactive exploration (and fired repeatedly during this session's testing). Replaced with a one-line pointer to `?quefts_soil` instead of actually invoking `help()`.

**Verification:** wrote a throwaway test script (not committed) that mocked `fetch_soilgrids_data()` (to avoid depending on the live, sometimes-500-returning SoilGrids API) and called `comprehensive_fertilizer_recommendation(lat=7.5, lon=-1.5, crop_name="Maize", target_yield=6000, fertilizer_prices=list(...), n_simulations=100)` for real. Confirmed: `report_generation_note` is `NULL` (no errors), `primary_recommendations`/`agronomic_insights`/`economic_analysis` are all populated with real, sensible values (e.g. agronomic insights correctly identified K as the primary limiting nutrient given the mock soil data), and `user_reports` contains all three rendered text reports (beginner/intermediate/expert), including a working traffic-light decision. Also re-verified `Rscript tests/test_integration.R` and a full `parse()` syntax check across all R files still pass after these changes.

**New finding, not fixed (out of scope for this phase):** with Step 5 finally reaching real data, its `sensitivity_ranking`/`most_sensitive` output carries a stray `.store_lim` suffix on parameter names (e.g. `"Exch_K.store_lim"` instead of `"Exch_K"`) that doesn't match `parameter_sensitivities`'s plain-named keys — likely from `sapply()` picking up a `names` attribute carried on a QUEFTS-internal named numeric deep in `calculate_sensitivity_slope()`/`relative_sensitivity`. This makes the "Parameter Sensitivity Ranking" list in the comprehensive text report print empty (the `param %in% names(...)` lookup never matches) and would affect the expert report's sensitivity section the same way. Cosmetic, not functionality-breaking (everything still returns and reports run), and a good candidate for a `testthat` regression test in Phase 4 rather than a quick fix now.

---

## Phase 4 — Automated Testing

*(§7 item 6 / §8.3)*

- [x] Convert manual `cat()`-driven validation scripts into a `testthat` suite under `tests/testthat/`, using existing hardcoded inputs as fixtures

#### Result / Implementation Notes
**2026-09-13** — Converted the six manual scripts (`quick_validation_test.R`, `simple_validation.R`, `simple_validation_test.R`, `test_integration.R`, `test_quefts_engine.R`, `validate_uncertainty_framework.R`) into a real `testthat` suite: 21 `test_that()` blocks, 107 expectations, run via `Rscript tests/testthat.R` from the project root. `testthat` (3.3.1) was already present in `renv.lock` as a transitive dependency from Phase 1. The three highly-overlapping module-existence scripts (`quick_validation_test.R`, `simple_validation.R`, `simple_validation_test.R`) were consolidated into one `test-module-loading.R`; the other three map roughly 1:1 to `test-quefts-engine.R`, `test-uncertainty-framework.R`, and `test-integration.R`. `test_quefts_engine.R`'s original exhaustive demo (7 scenarios × up to 4 crops × up to 6 yield targets) was trimmed to representative cases per scenario — regression coverage, not a full demo walkthrough (that's what `demo/` is for). `n_simulations` is 40 throughout (vs. the originals' 150-1000) to keep the suite fast; this is the same "reduced for faster testing" tradeoff the original scripts themselves already made.

**Structure:** `tests/testthat.R` (runner) → `testthat::test_dir("tests/testthat")`, which auto-sources `tests/testthat/helper-setup.R` (loads the whole system once, plus shared fixtures) before running the four `test-*.R` files.

**A real, non-obvious wiring problem:** `testthat::test_dir()` changes the working directory while it runs, which breaks every root-relative `source()` call inside the sourced R files (the Phase 2 convention). Fixed by having the runner capture `normalizePath(".")` into an env var (`QUEFTS_PROJECT_ROOT`) *before* calling `test_dir()`, and having the helper `withr::with_dir()` back into that root only for the initial sourcing. `bayesian_updating_module.R` also had to be sourced explicitly in the helper — it's a standalone module never `source()`-d by `integrated_decision_support.R`'s own chain (already flagged in `PROJECT_EVALUATION.md` §3/§6.8) but several tests exercise it directly.

**`test-integration.R` replaces a live network dependency with a deterministic mock:** the original `test_integration.R` called `get_multiscale_soil_data()` against the real SoilGrids API (already flagged as flaky in `PROJECT_EVALUATION.md` §6.3, and it returned a 500 during this very session's Phase 2/3 testing). The converted version instead reuses the `fetch_soilgrids_data()` mock built (and manually verified) during Phase 3, wired in via `assign(..., envir = globalenv())` since `get_multiscale_soil_data()` calls `fetch_soilgrids_data()` unqualified and looks it up by lexical scoping from the global environment, not from the calling `test_that()` block's own environment — a plain local reassignment would have been silently ignored. This makes the two `test-integration.R` tests exercise the **entire real pipeline, Steps 1-7 including the Phase 3 output-generation wiring**, deterministically, on every run.

**A fourth instance of the field-naming inconsistency first found in Phase 3:** building the Bayesian/sensitivity fixture (`fixture_bayesian_soil`) surfaced yet another spot where the same three soil properties need different field names depending which function reads them: `calculate_fertilizer_recommendation()` wants `SOC/Kex/Polsen`, `perform_sensitivity_analysis()`'s default `parameters` wants `SOC/Exch_K/Olsen_P`, and (new this phase) `calculate_native_supply()` — reached via `perform_enhanced_sensitivity_analysis()` → `perform_sensitivity_analysis()` → `calculate_fertilizer_needs()` — specifically wants `OC` (not `SOC`) alongside `Exch_K`/`Polsen`. Rather than patch a third internal function, the fixture just carries every alias (`SOC`, `OC`, `Kex`, `Exch_K`, `Polsen`, `Olsen_P`) pointing at the same values — safe since unused list fields are harmless, and this affects only test fixtures, not production code. Also had to capitalize the crop name (`"maize"` → `"Maize"`) in this same fixture: the real `Rquefts` package's bundled crop database is case-sensitive and `calculate_native_supply()` routes through it, while `quefts_calculation_engine.R`'s Monte Carlo engine (used by the other three tests) is not case-sensitive about crop names — so the original script's lowercase `"maize"` had apparently never actually been exercised against the real Rquefts crop lookup before.

**Old scripts retired, not deleted:** all six original manual scripts moved to `dev-history/` (`git mv`, no content changes) now that the `testthat` suite supersedes them, matching the "preserve don't delete" precedent set in Phase 2. `tests/` now contains only `testthat.R` and `testthat/`. `PROJECT_EVALUATION.md`'s file catalog (§4) still describes them at their old `tests/` location — left as-is per the same "dated snapshot, not retroactively edited" precedent from Phase 1/2.

**Verification:** full `parse()` syntax check across all 44 R files (up from 38, +6 for the new test files), and `Rscript tests/testthat.R` run twice in a row for reproducibility — both times exit code 0, 0 failures.

---

## Phase 5 — Data Assets

*(§8.4)*

- [x] Add sample/fixture soil datasets under `data/`; refactor hardcoded inline soil values in demo/test scripts to load from these fixtures

#### Result / Implementation Notes
**2026-09-13** — Added `data/sample_soil_profiles.csv`: 6 representative field profiles (one per supported crop — Maize ×2 at different fertility levels, Rice, Wheat, Soybean, Cassava — spanning all four data-quality tiers from `global_maps` to `laboratory_analyzed`), with canonical field names (`pH`, `SOC_g_kg`, `Total_N_g_kg`, `Olsen_P_mg_kg`, `Exch_K_mmol_kg`, `clay_pct`/`sand_pct`/`silt_pct`, `data_quality`). The Ghana maize profile's values were reverse-engineered from what `demo/demo_integrated_system.R` already had hardcoded (its old `demo_lab_results` matched exactly), so nothing was invented from scratch for the primary demo scenario.

**`R/core/sample_soil_data.R`** loads the CSV and adapts one profile to whichever of the (by now four distinct — see below) soil-field-naming conventions a given function needs: `soil_profile_as(profile, style)` for `"spatial"` (pH/OC/Total_N/Olsen_P/Exch_K), `"engine"` (pH/SOC/Kex/Polsen), or `"framework"` (pH/OC/Exch_K/Polsen). Also added `build_observation_sources(profile, ...)`, which derives a Bayesian-updating `observation_sources` block (global/lab/field tiers with different assumed CVs) from one profile's values instead of three independently hand-typed value/variance pairs.

**Refactored to load from the fixture instead of inline hardcoding:**
- `demo/comprehensive_framework_demo.R` — `demo_soil_data`/`demo_crop`/`demo_target_yield` now come from `get_sample_soil_profile("gh_maize_fertile")` via the `"engine"` adapter, plus `build_observation_sources()` for the Bayesian block.
- `demo/demo_integrated_system.R` — `demo_location$region`, `demo_crop`, and `demo_lab_results`' core fields (`pH`/`organic_carbon`/`total_nitrogen`/`olsen_p`/`exchangeable_k`/`texture`) now come from the same profile. The illustrative `global_data`/`regional_data` blocks (deliberately *different* from the lab values, to demonstrate uncertainty narrowing across data-quality tiers) were left hardcoded on purpose — sourcing them from the fixture would remove the contrast they exist to show.
- `tests/testthat/helper-setup.R` — `fixture_engine_soil`, `fixture_quefts_input_soil`, and `fixture_mock_soilgrids_data`'s base values now come from the same profile too, via the same adapters.
- `tests/testthat/test-uncertainty-framework.R`'s `fixture_bayesian_soil` was deliberately **left as its own hardcoded fixture** — its exact prior/posterior variance relationships were hand-tuned for that specific test (Bayesian uncertainty reduction) and already validated in Phase 4; forcing it onto a shared profile with different pH/SOC values would have meant re-validating those relationships for no real benefit, since the point of that fixture is the variance *pattern*, not the specific site.

**Two more pre-existing bugs found and fixed, discovered because this was the first time `demo/comprehensive_framework_demo.R` had ever actually been run to completion:**
1. `generate_agronomic_insights()`'s `analyze_nutrient_limitations()` reads `standard_results$detailed_results$soil_supply$<N|P|K>$mean`, which `calculate_fertilizer_recommendation()`'s raw output never populates (same gap identified and patched inside `integrated_decision_support.R` in Phase 3 — this demo script calls `generate_agronomic_insights()` directly, so it needed the same patch applied locally).
2. The expert-level `generate_progressive_disclosure()` call used `display_format = "text"` but then accessed the result as a structured list (`expert_interface$full_uncertainty_analysis` etc.) — `format_disclosure_output()` only returns a list for `display_format` values *other than* `"text"`/`"html"`/`"json"`; changed to `display_format = "list"` to match how the result is actually used.

**Verification:** full `parse()` syntax check across all 45 R files, `Rscript demo/comprehensive_framework_demo.R` and `Rscript demo/demo_integrated_system.R` both now run to completion with exit code 0 (the former for the first time ever, as far as this project's history shows), and the full `testthat` suite (Phase 4) still passes after the fixture refactor.

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
