# Converted from tests/quick_validation_test.R, tests/simple_validation.R,
# and tests/simple_validation_test.R (the three original manual scripts
# that all did essentially the same thing: check that modules load and key
# functions exist).

test_that("core calculation engine exposes its main functions", {
  expect_true(exists("calculate_fertilizer_recommendation"))
  expect_true(is.function(calculate_fertilizer_recommendation))
  expect_true(exists("get_crop_parameters"))
  expect_true(exists("nutSupply1_with_uncertainty"))
})

test_that("original QUEFTS framework exposes its main functions", {
  expect_true(exists("create_soil_test"))
  expect_true(exists("calculate_fertilizer_needs"))
  expect_true(exists("generate_fertilizer_report"))
})

test_that("uncertainty quantification module exposes its main functions", {
  expect_true(exists("run_quefts_with_uncertainty"))
  expect_true(exists("generate_probabilistic_recommendations"))
  expect_true(exists("make_uncertainty_based_decision"))
  expect_true(exists("perform_sensitivity_analysis"))
})

test_that("bayesian updating module exposes its main functions", {
  expect_true(exists("bayesian_update_soil_parameters"))
  expect_true(exists("calculate_fertilizer_recommendation_bayesian"))
})

test_that("spatial data integration module exposes its main function", {
  expect_true(exists("get_multiscale_soil_data"))
})

test_that("output generation and user interpretation modules exist", {
  expect_true(exists("generate_primary_recommendations"))
  expect_true(exists("generate_agronomic_insights"))
  expect_true(exists("generate_economic_analysis"))
  expect_true(exists("generate_progressive_disclosure"))
})

test_that("decision support layer exposes the top-level entry point", {
  expect_true(exists("comprehensive_fertilizer_recommendation"))
  expect_true(is.function(comprehensive_fertilizer_recommendation))
})

test_that("perform_sensitivity_analysis is the per-parameter version, not the shadowed one", {
  # Regression test for the Phase 3 name collision: quefts_soil_test_framework.R
  # used to define its own perform_sensitivity_analysis() (renamed to
  # perform_uncertainty_level_sensitivity_analysis in Phase 2) that silently
  # overwrote uncertainty_quantification.R's version because it was sourced
  # later. Confirm the *right* one is the one actually in scope.
  expect_true("parameters" %in% names(formals(perform_sensitivity_analysis)))
  expect_true("target_yield" %in% names(formals(perform_sensitivity_analysis)))
})

test_that("a minimal fertilizer calculation runs and returns sane values", {
  result <- calculate_fertilizer_recommendation(
    soil_data = fixture_engine_soil,
    crop = "Maize",
    target_yield = 6000,
    uncertainty_level = "medium",
    n_simulations = fixture_n_simulations
  )

  expect_type(result, "list")
  expect_true(all(c("N", "P", "K") %in% names(result$fertilizer_rates)))
  expect_true(is.numeric(result$fertilizer_rates$N))
  expect_gte(result$fertilizer_rates$N, 0)
  expect_gte(result$fertilizer_rates$P, 0)
  expect_gte(result$fertilizer_rates$K, 0)
  expect_true(result$probability_of_success >= 0 && result$probability_of_success <= 1)
})
