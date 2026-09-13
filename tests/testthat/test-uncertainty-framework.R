# Converted from tests/validate_uncertainty_framework.R. Uses the same
# multi-source soil data fixture as the original script (needed for the
# Bayesian updating test's observation_sources), but with a much smaller
# n_simulations for speed.

fixture_bayesian_soil <- list(
  pH = 5.8,
  # Every alias for organic carbon / K / P below is included because
  # different functions in this call chain want different field names for
  # the same three soil properties: calculate_fertilizer_recommendation()
  # (quefts_calculation_engine.R) wants SOC/Kex/Polsen,
  # perform_sensitivity_analysis()'s default `parameters`
  # (uncertainty_quantification.R) wants SOC/Exch_K/Olsen_P, and
  # calculate_native_supply() (quefts_soil_test_framework.R, reached via
  # calculate_fertilizer_needs()) wants OC/Exch_K/Polsen. This is a third,
  # independent instance of the naming inconsistency first found in Phase 3
  # -- see PROJECT_TRACKER.md Phase 4 for the full discovery.
  SOC = 18.5,
  OC = 18.5,
  Kex = 4.2,
  Exch_K = 4.2,
  Polsen = 8.5,
  Olsen_P = 8.5,
  clay = 35,
  sand = 45,
  observation_sources = list(
    global_maps = list(
      pH = list(value = 5.9, variance = 0.3),
      SOC = list(value = 20.0, variance = 50),
      Kex = list(value = 4.0, variance = 2.5),
      Polsen = list(value = 9.0, variance = 15)
    ),
    laboratory_analysis = list(
      pH = list(value = 5.8, variance = 0.01),
      SOC = list(value = 18.5, variance = 5),
      Kex = list(value = 4.2, variance = 0.5),
      Polsen = list(value = 8.5, variance = 2)
    ),
    field_observations = list(
      pH = list(value = 5.7, variance = 0.1),
      SOC = list(value = 19.0, variance = 20)
    )
  )
)

test_that("Monte Carlo simulation produces samples and 50/80/95 confidence intervals", {
  result <- calculate_fertilizer_recommendation(
    soil_data = fixture_bayesian_soil,
    crop = "Maize",
    target_yield = 6000,
    uncertainty_level = "medium",
    n_simulations = fixture_n_simulations
  )

  N_rates <- result$detailed_results$fertilizer_rates$N
  expect_equal(length(N_rates$samples), fixture_n_simulations)

  for (level in c("confidence_50", "confidence_80", "confidence_95")) {
    expect_true(level %in% names(N_rates), info = level)
    expect_length(N_rates[[level]], 2)
    expect_lte(N_rates[[level]][1], N_rates[[level]][2])
  }
})

test_that("Bayesian updating reduces uncertainty relative to the prior", {
  bayesian_result <- calculate_fertilizer_recommendation_bayesian(
    soil_data = fixture_bayesian_soil,
    crop = "Maize",
    target_yield = 6000,
    prior_source = "global",
    update_priors = TRUE,
    n_simulations = fixture_n_simulations
  )

  expect_false(is.null(bayesian_result$bayesian_updating))

  for (param in names(bayesian_result$bayesian_updating)) {
    update_info <- bayesian_result$bayesian_updating[[param]]
    posterior_variance <- update_info$posterior$variance
    prior_variance <- update_info$prior$variance
    # Bayesian updating with additional, more-precise observations
    # (laboratory + field data on top of the global prior) should not
    # increase uncertainty.
    expect_lte(posterior_variance, prior_variance, label = param)
  }
})

test_that("enhanced sensitivity analysis returns a parameter ranking", {
  sensitivity_result <- perform_enhanced_sensitivity_analysis(
    soil_data = fixture_bayesian_soil,
    crop_name = "Maize",
    target_yield = 6000,
    include_bayesian = TRUE
  )

  expect_false(is.null(sensitivity_result$standard_sensitivity))
  expect_true("sensitivity_ranking" %in% names(sensitivity_result$standard_sensitivity))
  expect_gt(length(sensitivity_result$standard_sensitivity$sensitivity_ranking), 0)
})

test_that("framework compliance components are all present (the original script's compliance score)", {
  # Reproduces validate_uncertainty_framework.R's "Framework Compliance
  # Summary" as real assertions instead of a printed percentage.
  monte_carlo_result <- calculate_fertilizer_recommendation(
    soil_data = fixture_bayesian_soil,
    crop = "Maize",
    target_yield = 6000,
    uncertainty_level = "medium",
    n_simulations = fixture_n_simulations
  )
  bayesian_result <- calculate_fertilizer_recommendation_bayesian(
    soil_data = fixture_bayesian_soil,
    crop = "Maize",
    target_yield = 6000,
    prior_source = "global",
    update_priors = TRUE,
    n_simulations = fixture_n_simulations
  )
  sensitivity_result <- perform_enhanced_sensitivity_analysis(
    soil_data = fixture_bayesian_soil,
    crop_name = "Maize",
    target_yield = 6000,
    include_bayesian = TRUE
  )

  N_rates <- monte_carlo_result$detailed_results$fertilizer_rates$N
  compliance <- list(
    monte_carlo = length(N_rates$samples) == fixture_n_simulations,
    bayesian_updating = !is.null(bayesian_result$bayesian_updating),
    sensitivity_analysis = !is.null(sensitivity_result$standard_sensitivity),
    confidence_50 = "confidence_50" %in% names(N_rates),
    confidence_80 = "confidence_80" %in% names(N_rates),
    confidence_95 = "confidence_95" %in% names(N_rates)
  )

  for (component in names(compliance)) {
    expect_true(compliance[[component]], label = component)
  }
})
