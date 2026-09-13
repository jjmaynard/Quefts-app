# Converted from tests/test_quefts_engine.R. Trimmed from the original's
# exhaustive demo (7 tests x up to 4 crops x up to 6 targets, ~300+ lines)
# to representative cases per scenario -- the goal here is regression
# coverage, not a full demo walkthrough (that's what demo/ is for).

test_that("basic fertilizer recommendation has the expected structure", {
  result <- calculate_fertilizer_recommendation(
    soil_data = fixture_engine_soil,
    crop = "Maize",
    target_yield = 6000,
    uncertainty_level = "medium",
    n_simulations = fixture_n_simulations
  )

  expect_true(all(c("N", "P", "K") %in% names(result$fertilizer_rates)))
  expect_true(all(c("lower_80", "upper_80") %in% names(result$confidence_intervals$N)))
  expect_true(result$confidence_intervals$N$lower_80 <= result$confidence_intervals$N$upper_80)
  expect_gte(result$yield_prediction$expected, 0)
  expect_true(!is.null(result$detailed_results))
  expect_true(!is.null(result$soil_supply_analysis))
})

test_that("all three uncertainty levels run and produce a risk estimate", {
  for (level in c("low", "medium", "high")) {
    result <- calculate_fertilizer_recommendation(
      soil_data = fixture_engine_soil,
      crop = "Maize",
      target_yield = 6000,
      uncertainty_level = level,
      n_simulations = fixture_n_simulations
    )
    expect_true(is.numeric(result$risk_assessment$overall_uncertainty), info = level)
    expect_gte(result$risk_assessment$overall_uncertainty, 0)
  }
})

test_that("multiple crops each produce valid recommendations", {
  for (crop in c("Maize", "Rice", "Soybean")) {
    result <- calculate_fertilizer_recommendation(
      soil_data = fixture_engine_soil,
      crop = crop,
      target_yield = 5000,
      uncertainty_level = "medium",
      n_simulations = fixture_n_simulations
    )
    expect_gte(result$fertilizer_rates$N, 0, label = paste("N rate for", crop))
    expect_gte(result$fertilizer_rates$P, 0, label = paste("P rate for", crop))
    expect_gte(result$fertilizer_rates$K, 0, label = paste("K rate for", crop))
  }
})

test_that("economic analysis returns a coherent profit probability", {
  economic_params <- list(
    N_price = list(mean = 1.2, sd = 0.15),
    P_price = list(mean = 2.5, sd = 0.30),
    K_price = list(mean = 1.0, sd = 0.12),
    crop_price = list(mean = 0.30, sd = 0.03),
    application_cost = list(mean = 25, sd = 5)
  )

  result <- calculate_fertilizer_recommendation(
    soil_data = fixture_engine_soil,
    crop = "Maize",
    target_yield = 6000,
    uncertainty_level = "medium",
    economic_params = economic_params,
    n_simulations = fixture_n_simulations
  )

  expect_false(is.null(result$economic_risk))
  expect_true(result$economic_risk$probability_of_profit >= 0 &&
                result$economic_risk$probability_of_profit <= 1)
  expect_true(is.numeric(result$economic_risk$net_profit$mean))
})

test_that("soil supply uncertainty returns sane N/P/K supply statistics", {
  soil_supply_result <- nutSupply1_with_uncertainty(
    pH = fixture_engine_soil$pH,
    SOC = fixture_engine_soil$SOC,
    Kex = fixture_engine_soil$Kex,
    Polsen = fixture_engine_soil$Polsen,
    n_samples = 200
  )

  for (nutrient in c("N_supply", "P_supply", "K_supply")) {
    supply <- soil_supply_result[[nutrient]]
    expect_gte(supply$mean, 0, label = nutrient)
    expect_gte(supply$sd, 0, label = nutrient)
    expect_true(is.finite(supply$cv), label = nutrient)
  }
})

test_that("yield target sensitivity produces valid results across a range of targets", {
  for (target in c(4000, 6000, 8000)) {
    result <- calculate_fertilizer_recommendation(
      soil_data = fixture_engine_soil,
      crop = "Maize",
      target_yield = target,
      uncertainty_level = "medium",
      n_simulations = fixture_n_simulations
    )
    expect_gte(result$fertilizer_rates$N, 0, label = paste("target", target))
    expect_gte(result$yield_prediction$expected, 0, label = paste("target", target))
  }
})
