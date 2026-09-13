# Auto-sourced by testthat::test_dir() before any test-*.R file runs.
#
# Loads the whole system once (R/decision_support/integrated_decision_support.R
# transitively sources every module plus the core framework, and already
# includes the rmarkdown/Rquefts::run() masking fix from Phase 3), and
# defines fixtures shared across test files.

project_root <- Sys.getenv("QUEFTS_PROJECT_ROOT", unset = NA)
if (is.na(project_root) || !nzchar(project_root)) {
  stop(
    "QUEFTS_PROJECT_ROOT is not set. Run the suite via `Rscript tests/testthat.R` ",
    "from the project root, not testthat::test_dir() directly."
  )
}

# integrated_decision_support.R (and everything it transitively sources)
# uses project-root-relative paths, per the convention established in
# PROJECT_TRACKER.md Phase 2 -- but testthat::test_dir() changes the working
# directory to tests/testthat while sourcing helpers, so those relative
# paths would break unless we source from the project root instead.
invisible(capture.output(suppressMessages(suppressWarnings(
  withr::with_dir(project_root, {
    source("R/core/sample_soil_data.R")
    source("R/decision_support/integrated_decision_support.R")
    # bayesian_updating_module.R is a standalone module never source()-d by
    # integrated_decision_support.R's own chain (see PROJECT_EVALUATION.md
    # Sec 3/6.8) -- load it explicitly since tests exercise it directly.
    source("R/modules/bayesian_updating_module.R")
  })
))))

# ------------------------------------------------------------------------
# Shared fixtures, derived from data/sample_soil_profiles.csv (Phase 5)
# rather than hardcoded inline -- these values previously duplicated the
# manual scripts' own hardcoded soil-test values (e.g. the original
# tests/test_quefts_engine.R's test_soil, tests/validate_uncertainty_framework.R's
# test_soil_data) and happen to match the "gh_maize_fertile" sample profile.
# ------------------------------------------------------------------------

fixture_profile <- get_sample_soil_profile(
  "gh_maize_fertile",
  profiles = load_sample_soil_profiles(file.path(project_root, "data/sample_soil_profiles.csv"))
)

# Shape expected by quefts_calculation_engine.R's
# calculate_fertilizer_recommendation() and nutSupply1_with_uncertainty().
fixture_engine_soil <- soil_profile_as(fixture_profile, "engine")

# Shape expected by uncertainty_quantification.R's run_quefts_with_uncertainty()
# and perform_sensitivity_analysis() (via spatial_data$quefts_input's field
# names: pH/OC/Exch_K/Olsen_P, not pH/SOC/Kex/Polsen -- see PROJECT_TRACKER.md
# Phase 3 for why these two conventions coexist).
fixture_quefts_input_soil <- c(
  soil_profile_as(fixture_profile, "spatial"),
  list(data_quality = "laboratory_analyzed", uncertainty_tier = 4)
)

# Mock for fetch_soilgrids_data(), so integration tests don't depend on the
# live SoilGrids API (which is flaky -- see PROJECT_EVALUATION.md Sec 6.3 and
# PROJECT_TRACKER.md Phase 2/3 notes). Matches the shape
# convert_soilgrids_to_quefts() actually returns. Uncertainty estimates below
# are illustrative (representing SoilGrids' own reported uncertainty), not
# part of the shared profile schema.
fixture_mock_soilgrids_data <- function(lat, lon, ...) {
  list(
    # NOTE: this must use "SOC" (matching what a real fetch_soilgrids_data()
    # call produces, per convert_soilgrids_to_quefts()), NOT the "OC" name
    # convert_to_quefts_input() renames it to downstream -- get_multiscale_soil_data()
    # does that renaming itself when building spatial_data$quefts_input, so
    # mocking fetch_soilgrids_data() must hand it the pre-rename shape.
    soil_properties = list(
      pH = fixture_profile$pH, SOC = fixture_profile$OC, Total_N = fixture_profile$Total_N,
      Olsen_P = fixture_profile$Olsen_P, Exch_K = fixture_profile$Exch_K,
      clay = fixture_profile$clay, sand = fixture_profile$sand, silt = fixture_profile$silt
    ),
    uncertainties = list(
      pH = 0.3, SOC = 3, Total_N = 0.2, Olsen_P = 6, Exch_K = 4,
      clay = 5, sand = 5, silt = 5, bulk_density = 0.1, CEC = 3
    ),
    data_quality = "global_maps",
    uncertainty_level = "high",
    source = "MOCK_SoilGrids (testthat fixture)",
    uncertainty_tier = 1,
    spatial_resolution = "250m",
    coordinates = list(lat = lat, lon = lon),
    fetch_date = Sys.Date()
  )
}

# Keep Monte Carlo simulation counts small so the suite runs quickly; the
# original manual scripts already did this for the same reason ("Reduced
# for faster testing").
fixture_n_simulations <- 40
