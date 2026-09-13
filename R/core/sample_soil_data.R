# ================================================================================
# SAMPLE SOIL DATA FIXTURES
# Loads data/sample_soil_profiles.csv and adapts it to whichever soil-data
# field-naming convention a given function in this project expects.
#
# Background: across Phases 3-4 (see PROJECT_TRACKER.md) the same three soil
# properties (organic carbon, exchangeable K, available P) turned out to have
# at least four different expected field names depending which function reads
# them:
#   - "engine"     (quefts_calculation_engine.R):        SOC, Kex,    Polsen
#   - "spatial"     (spatial_data_integration.R):         OC,  Exch_K, Olsen_P
#   - "sensitivity" (uncertainty_quantification.R default): SOC, Exch_K, Olsen_P
#   - "framework"   (quefts_soil_test_framework.R's
#                     calculate_native_supply()):          OC,  Exch_K, Polsen
# Rather than adding a fifth ad hoc alias set wherever new code needs sample
# data, soil_profile_as() centralizes the conversion in one place.
# ================================================================================

#' Load the sample soil profile table
#'
#' @param path Path to the CSV, relative to the project root.
#' @return A data.frame, one row per profile.
load_sample_soil_profiles <- function(path = "data/sample_soil_profiles.csv") {
  read.csv(path, stringsAsFactors = FALSE)
}

#' Get one sample soil profile as a canonical list
#'
#' The canonical shape mirrors spatial_data_integration.R's convention
#' (pH/OC/Total_N/Olsen_P/Exch_K), since that's the field-facing pipeline
#' (get_multiscale_soil_data() -> convert_to_quefts_input()) sample data is
#' most likely to stand in for. Use soil_profile_as() to convert to whatever
#' shape the function you're calling actually needs.
#'
#' @param profile_id One of the `profile_id` values in
#'   data/sample_soil_profiles.csv (e.g. "gh_maize_fertile").
#' @param profiles Optional pre-loaded data.frame from
#'   load_sample_soil_profiles(), to avoid re-reading the CSV in a loop.
get_sample_soil_profile <- function(profile_id, profiles = NULL) {
  if (is.null(profiles)) {
    profiles <- load_sample_soil_profiles()
  }

  row <- profiles[profiles$profile_id == profile_id, ]
  if (nrow(row) == 0) {
    stop(
      "Unknown profile_id '", profile_id, "'. Available: ",
      paste(profiles$profile_id, collapse = ", ")
    )
  }

  list(
    profile_id = row$profile_id,
    site_name = row$site_name,
    region = row$region,
    crop = row$crop,
    target_yield = row$target_yield_kg_ha,
    pH = row$pH,
    OC = row$SOC_g_kg,
    Total_N = row$Total_N_g_kg,
    Olsen_P = row$Olsen_P_mg_kg,
    Exch_K = row$Exch_K_mmol_kg,
    clay = row$clay_pct,
    sand = row$sand_pct,
    silt = row$silt_pct,
    data_quality = row$data_quality,
    notes = row$notes
  )
}

#' Adapt a canonical soil profile to a specific function's expected field names
#'
#' @param profile A list from get_sample_soil_profile().
#' @param style One of "spatial" (pH/OC/Total_N/Olsen_P/Exch_K -- the
#'   canonical shape itself, returned as-is), "engine" (pH/SOC/Kex/Polsen,
#'   for quefts_calculation_engine.R), or "framework" (pH/OC/Exch_K/Polsen,
#'   for quefts_soil_test_framework.R's calculate_native_supply()).
#' @return A list with just the renamed soil-property fields (plus
#'   `site_name`), ready to pass as `soil_data`.
soil_profile_as <- function(profile, style = c("spatial", "engine", "framework")) {
  style <- match.arg(style)

  switch(style,
    spatial = list(
      site_name = profile$site_name,
      pH = profile$pH,
      OC = profile$OC,
      Total_N = profile$Total_N,
      Olsen_P = profile$Olsen_P,
      Exch_K = profile$Exch_K,
      clay = profile$clay,
      sand = profile$sand,
      silt = profile$silt
    ),
    engine = list(
      site_name = profile$site_name,
      pH = profile$pH,
      SOC = profile$OC,
      Kex = profile$Exch_K,
      Polsen = profile$Olsen_P,
      clay = profile$clay,
      sand = profile$sand
    ),
    framework = list(
      site_name = profile$site_name,
      pH = profile$pH,
      OC = profile$OC,
      Exch_K = profile$Exch_K,
      Polsen = profile$Olsen_P,
      Total_N = profile$Total_N
    )
  )
}

#' Derive multi-tier Bayesian observation_sources from one sample profile
#'
#' Several scripts (e.g. demo/comprehensive_framework_demo.R,
#' tests/testthat/test-uncertainty-framework.R) need a soil_data$observation_sources
#' block for calculate_fertilizer_recommendation_bayesian() -- global/lab/field
#' estimates of the same properties with different variances. Rather than
#' hand-typing three independently-guessed value/variance pairs (as the
#' original scripts did), derive all three tiers from one profile's values
#' plus a documented per-tier uncertainty percentage, so there's one source
#' of truth for "what this site's soil is actually like."
#'
#' @param profile A list from get_sample_soil_profile().
#' @param global_cv,lab_cv,field_cv Coefficient of variation (sd/mean) to
#'   apply at each tier; global (SoilGrids-like) is least precise, lab most.
#' @return A list with `global_maps`, `laboratory_analysis`, and
#'   `field_observations` entries, each a list of `list(value, variance)`
#'   for pH, SOC, Kex (as Polsen/Kex, matching the engine naming these
#'   Bayesian functions use), suitable for `soil_data$observation_sources`.
build_observation_sources <- function(profile, global_cv = 0.15, lab_cv = 0.03, field_cv = 0.08) {
  make_tier <- function(cv, include_all = TRUE) {
    tier <- list(
      pH = list(value = profile$pH, variance = (profile$pH * cv) ^ 2),
      SOC = list(value = profile$OC, variance = (profile$OC * cv) ^ 2)
    )
    if (include_all) {
      tier$Kex <- list(value = profile$Exch_K, variance = (profile$Exch_K * cv) ^ 2)
      tier$Polsen <- list(value = profile$Olsen_P, variance = (profile$Olsen_P * cv) ^ 2)
    }
    tier
  }

  list(
    global_maps = make_tier(global_cv),
    laboratory_analysis = make_tier(lab_cv),
    field_observations = make_tier(field_cv, include_all = FALSE)
  )
}
