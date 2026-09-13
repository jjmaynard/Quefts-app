# ================================================================================
# INTEGRATED DECISION SUPPORT SYSTEM
# Combining Spatial Data Integration + Uncertainty Quantification + QUEFTS
# ================================================================================

# Load required modules
source("R/modules/spatial_data_integration.R")
source("R/modules/uncertainty_quantification.R")
source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")

cat("Loading Integrated Decision Support System...\n")

# ================================================================================
# 1. COMPREHENSIVE DECISION SUPPORT FUNCTION
# ================================================================================

#' Comprehensive fertilizer recommendation with uncertainty analysis
#' 
#' @param lat Latitude coordinate
#' @param lon Longitude coordinate
#' @param crop_name Target crop
#' @param target_yield Target yield (kg/ha)
#' @param region Optional region code for calibration
#' @param field_observations Optional field observations
#' @param lab_results Optional laboratory results
#' @param fertilizer_prices Economic parameters
#' @param risk_tolerance Risk tolerance level
#' @param n_simulations Number of Monte Carlo simulations
#' @param confidence_levels Confidence levels for recommendations
comprehensive_fertilizer_recommendation <- function(lat, lon, crop_name, target_yield,
                                                  region = NULL,
                                                  field_observations = NULL,
                                                  lab_results = NULL,
                                                  fertilizer_prices = NULL,
                                                  risk_tolerance = "moderate",
                                                  n_simulations = 1000,
                                                  confidence_levels = c(0.5, 0.8, 0.95)) {
  
  cat("=== COMPREHENSIVE FERTILIZER RECOMMENDATION SYSTEM ===\n")
  cat("Location:", lat, ",", lon, "\n")
  cat("Crop:", crop_name, "\n")
  cat("Target Yield:", target_yield, "kg/ha\n\n")
  
  # Step 1: Get multi-scale soil data
  cat("STEP 1: SPATIAL DATA INTEGRATION\n")
  spatial_data <- get_multiscale_soil_data(
    lat = lat,
    lon = lon,
    region = region,
    field_observations = field_observations,
    lab_results = lab_results
  )
  
  if (is.null(spatial_data)) {
    stop("Could not retrieve soil data for this location")
  }
  
  # Step 2: Run QUEFTS with uncertainty propagation
  cat("\nSTEP 2: UNCERTAINTY QUANTIFICATION\n")
  uncertainty_results <- run_quefts_with_uncertainty(
    soil_data = spatial_data$raw_data,
    crop_name = crop_name,
    target_yield = target_yield,
    fertilizer_prices = fertilizer_prices,
    n_simulations = n_simulations
  )
  
  # Step 3: Generate probabilistic recommendations
  cat("\nSTEP 3: PROBABILISTIC RECOMMENDATIONS\n")
  probabilistic_recs <- generate_probabilistic_recommendations(
    uncertainty_results, 
    confidence_levels
  )
  
  # Step 4: Make uncertainty-based decision
  cat("\nSTEP 4: DECISION ANALYSIS\n")
  decision <- make_uncertainty_based_decision(
    uncertainty_results, 
    risk_tolerance
  )
  
  # Step 5: Sensitivity analysis
  cat("\nSTEP 5: SENSITIVITY ANALYSIS\n")
  sensitivity_analysis <- perform_sensitivity_analysis(
    soil_data = spatial_data$quefts_input,
    crop_name = crop_name,
    target_yield = target_yield
  )
  
  # Compile comprehensive results
  comprehensive_results <- list(
    # Input information
    input_parameters = list(
      location = list(lat = lat, lon = lon),
      crop = crop_name,
      target_yield = target_yield,
      region = region,
      risk_tolerance = risk_tolerance,
      analysis_date = Sys.time()
    ),
    
    # Spatial data integration results
    spatial_analysis = list(
      data_sources = spatial_data$raw_data$data_sources,
      data_quality = spatial_data$raw_data$data_quality,
      uncertainty_tier = spatial_data$raw_data$uncertainty_tier,
      spatial_resolution = spatial_data$raw_data$spatial_resolution,
      soil_properties = spatial_data$raw_data$soil_properties,
      improvement_recommendations = spatial_data$data_summary$improvement_recommendations
    ),
    
    # Uncertainty analysis results
    uncertainty_analysis = uncertainty_results,
    
    # Probabilistic recommendations
    probabilistic_recommendations = probabilistic_recs,
    
    # Final decision
    decision_recommendation = decision,
    
    # Sensitivity analysis
    sensitivity_analysis = sensitivity_analysis,
    
    # Raw data for further analysis
    raw_spatial_data = spatial_data,
    quefts_input_data = spatial_data$quefts_input
  )
  
  # Generate comprehensive report
  cat("\nSTEP 6: GENERATING COMPREHENSIVE REPORT\n")
  generate_comprehensive_report(comprehensive_results)
  
  return(comprehensive_results)
}

# ================================================================================
# 2. SCENARIO ANALYSIS FUNCTIONS
# ================================================================================

#' Compare recommendations across different data quality scenarios
compare_data_quality_scenarios <- function(lat, lon, crop_name, target_yield, 
                                         field_observations = NULL, 
                                         lab_results = NULL,
                                         fertilizer_prices = NULL) {
  
  cat("=== DATA QUALITY SCENARIO COMPARISON ===\n")
  
  scenarios <- list(
    "Global Only" = list(region = NULL, field_obs = NULL, lab = NULL),
    "Regional Refined" = list(region = "Sub-Saharan_Africa", field_obs = NULL, lab = NULL),
    "Field Observed" = list(region = "Sub-Saharan_Africa", field_obs = field_observations, lab = NULL),
    "Lab Analyzed" = list(region = "Sub-Saharan_Africa", field_obs = field_observations, lab = lab_results)
  )
  
  scenario_results <- list()
  
  for (scenario_name in names(scenarios)) {
    cat("\nAnalyzing scenario:", scenario_name, "\n")
    
    scenario <- scenarios[[scenario_name]]
    
    # Get recommendations for this scenario
    result <- comprehensive_fertilizer_recommendation(
      lat = lat,
      lon = lon,
      crop_name = crop_name,
      target_yield = target_yield,
      region = scenario$region,
      field_observations = scenario$field_obs,
      lab_results = scenario$lab,
      fertilizer_prices = fertilizer_prices,
      n_simulations = 500  # Reduced for comparison
    )
    
    # Extract key metrics for comparison
    scenario_results[[scenario_name]] <- list(
      data_quality = result$spatial_analysis$data_quality,
      uncertainty_tier = result$spatial_analysis$uncertainty_tier,
      fertilizer_rates = result$probabilistic_recommendations$conf_80$fertilizer_rates,
      expected_yield = result$probabilistic_recommendations$conf_80$expected_yield,
      success_probability = result$uncertainty_analysis$success_probability,
      risk_score = result$uncertainty_analysis$risk_assessment$overall_risk_score,
      decision = result$decision_recommendation$recommendation
    )
  }
  
  # Generate comparison report
  generate_scenario_comparison_report(scenario_results)
  
  return(scenario_results)
}

#' Analyze impact of different yield targets
analyze_yield_target_sensitivity <- function(lat, lon, crop_name, 
                                           base_target = 6000,
                                           target_range = c(0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3),
                                           soil_data = NULL,
                                           fertilizer_prices = NULL) {
  
  cat("=== YIELD TARGET SENSITIVITY ANALYSIS ===\n")
  
  # If no soil data provided, get basic spatial data
  if (is.null(soil_data)) {
    spatial_data <- get_multiscale_soil_data(lat, lon)
    soil_data <- spatial_data$raw_data
  }
  
  target_results <- list()
  
  for (multiplier in target_range) {
    target_yield <- base_target * multiplier
    cat(sprintf("\nAnalyzing target yield: %.0f kg/ha (%.0f%% of base)\n", 
                target_yield, multiplier * 100))
    
    # Run uncertainty analysis
    uncertainty_results <- run_quefts_with_uncertainty(
      soil_data = soil_data,
      crop_name = crop_name,
      target_yield = target_yield,
      fertilizer_prices = fertilizer_prices,
      n_simulations = 500
    )
    
    # Extract key metrics
    target_results[[as.character(target_yield)]] <- list(
      target_yield = target_yield,
      multiplier = multiplier,
      fertilizer_rates = list(
        N = uncertainty_results$fertilizer_recommendations$N$median,
        P = uncertainty_results$fertilizer_recommendations$P$median,
        K = uncertainty_results$fertilizer_recommendations$K$median
      ),
      expected_yield = uncertainty_results$yield_predictions$predicted$median,
      success_probability = uncertainty_results$success_probability,
      economic_return = ifelse(!is.null(uncertainty_results$economic_analysis),
                              uncertainty_results$economic_analysis$median_return, NA)
    )
  }
  
  # Generate yield sensitivity report
  generate_yield_sensitivity_report(target_results, base_target)
  
  return(target_results)
}

# ================================================================================
# 3. COMPREHENSIVE REPORTING FUNCTIONS
# ================================================================================

#' Generate comprehensive analysis report
generate_comprehensive_report <- function(results) {
  
  cat("\n")
  cat("================================================================================\n")
  cat("                    COMPREHENSIVE FERTILIZER RECOMMENDATION REPORT\n")
  cat("================================================================================\n")
  cat("Analysis Date:", format(results$input_parameters$analysis_date), "\n")
  cat("Location:", results$input_parameters$location$lat, ",", results$input_parameters$location$lon, "\n")
  cat("Crop:", results$input_parameters$crop, "\n")
  cat("Target Yield:", results$input_parameters$target_yield, "kg/ha\n")
  cat("Risk Tolerance:", results$input_parameters$risk_tolerance, "\n")
  cat("================================================================================\n\n")
  
  # SECTION 1: DATA QUALITY ASSESSMENT
  cat("1. DATA QUALITY ASSESSMENT\n")
  cat("─────────────────────────────────────────────────────────────────────────────\n")
  spatial <- results$spatial_analysis
  cat("Data Quality Level:", spatial$data_quality, "\n")
  cat("Uncertainty Tier:", spatial$uncertainty_tier, "/ 4\n")
  cat("Spatial Resolution:", spatial$spatial_resolution, "\n")
  
  cat("\nData Sources Used:\n")
  for (source in names(spatial$data_sources)) {
    if (spatial$data_sources[[source]]) {
      cat("  ✓", tools::toTitleCase(source), "data included\n")
    }
  }
  
  cat("\nSoil Properties:\n")
  props <- spatial$soil_properties
  cat(sprintf("  pH: %.2f\n", props$pH))
  cat(sprintf("  Organic Carbon: %.1f g/kg\n", props$SOC))
  cat(sprintf("  Available P: %.1f mg/kg\n", props$Olsen_P))
  cat(sprintf("  Exchangeable K: %.1f mmol/kg\n", props$Exch_K))
  
  if (length(spatial$improvement_recommendations) > 0) {
    cat("\nData Improvement Recommendations:\n")
    for (rec in spatial$improvement_recommendations) {
      cat("  •", rec, "\n")
    }
  }
  
  # SECTION 2: FERTILIZER RECOMMENDATIONS
  cat("\n2. PROBABILISTIC FERTILIZER RECOMMENDATIONS\n")
  cat("─────────────────────────────────────────────────────────────────────────────\n")
  
  # 80% confidence interval recommendations
  conf_80 <- results$probabilistic_recommendations$conf_80
  cat("Recommended Rates (80% Confidence Intervals):\n")
  cat(sprintf("  Nitrogen (N):   %6.1f kg/ha  [%6.1f - %6.1f]\n",
              conf_80$fertilizer_rates$N$median,
              conf_80$fertilizer_rates$N$lower_ci,
              conf_80$fertilizer_rates$N$upper_ci))
  cat(sprintf("  Phosphorus (P): %6.1f kg/ha  [%6.1f - %6.1f]\n",
              conf_80$fertilizer_rates$P$median,
              conf_80$fertilizer_rates$P$lower_ci,
              conf_80$fertilizer_rates$P$upper_ci))
  cat(sprintf("  Potassium (K):  %6.1f kg/ha  [%6.1f - %6.1f]\n",
              conf_80$fertilizer_rates$K$median,
              conf_80$fertilizer_rates$K$lower_ci,
              conf_80$fertilizer_rates$K$upper_ci))
  
  cat(sprintf("\nExpected Yield: %6.0f kg/ha  [%6.0f - %6.0f]\n",
              conf_80$expected_yield$median,
              conf_80$expected_yield$lower_ci,
              conf_80$expected_yield$upper_ci))
  
  cat(sprintf("Probability of Achieving Target (%.0f kg/ha): %.1f%%\n",
              results$input_parameters$target_yield,
              results$uncertainty_analysis$success_probability * 100))
  
  # SECTION 3: RISK ASSESSMENT
  cat("\n3. RISK ASSESSMENT\n")
  cat("─────────────────────────────────────────────────────────────────────────────\n")
  risk <- results$uncertainty_analysis$risk_assessment
  cat("Overall Risk Category:", risk$risk_category, "\n")
  cat(sprintf("Risk Score: %.2f / 1.0\n", risk$overall_risk_score))
  
  if (!is.null(risk$fertilizer_uncertainty)) {
    cat(sprintf("Fertilizer Rate Uncertainty: %.1f%% (coefficient of variation)\n",
                risk$fertilizer_uncertainty$overall_cv * 100))
  }
  
  if (!is.null(risk$yield_risk)) {
    cat(sprintf("Yield Prediction Uncertainty: %.1f%% (coefficient of variation)\n",
                risk$yield_risk$cv * 100))
  }
  
  # Economic risk if available
  if (!is.null(results$uncertainty_analysis$economic_analysis)) {
    econ <- results$uncertainty_analysis$economic_analysis
    cat(sprintf("\nEconomic Analysis:\n"))
    cat(sprintf("  Expected Return: $%.0f per hectare\n", econ$mean_return))
    cat(sprintf("  Probability of Profit: %.1f%%\n", econ$prob_profit * 100))
    cat(sprintf("  Value at Risk (95%%): $%.0f\n", econ$var_95))
  }
  
  # SECTION 4: DECISION RECOMMENDATION
  cat("\n4. DECISION RECOMMENDATION\n")
  cat("─────────────────────────────────────────────────────────────────────────────\n")
  decision <- results$decision_recommendation
  cat("RECOMMENDATION:", decision$recommendation, "\n")
  cat("CONFIDENCE LEVEL:", decision$confidence, "\n")
  
  cat("\nJustification:\n")
  for (reason in decision$rationale) {
    cat("  •", reason, "\n")
  }
  
  # SECTION 5: SENSITIVITY ANALYSIS
  cat("\n5. SENSITIVITY ANALYSIS\n")
  cat("─────────────────────────────────────────────────────────────────────────────\n")
  sens <- results$sensitivity_analysis
  cat("Most Influential Parameter:", sens$most_sensitive, "\n")
  cat("Parameter Sensitivity Ranking:\n")
  for (i in seq_along(sens$sensitivity_ranking)) {
    param <- sens$sensitivity_ranking[i]
    if (param %in% names(sens$parameter_sensitivities)) {
      rel_sens <- sens$parameter_sensitivities[[param]]$relative_sensitivity
      cat(sprintf("  %d. %-10s (%.1f%% relative sensitivity)\n", 
                  i, param, rel_sens * 100))
    }
  }
  
  # SECTION 6: IMPLEMENTATION GUIDANCE
  cat("\n6. IMPLEMENTATION GUIDANCE\n")
  cat("─────────────────────────────────────────────────────────────────────────────\n")
  
  if (decision$recommendation == "APPLY_FERTILIZER") {
    cat("Implementation Strategy:\n")
    cat("  • Apply fertilizer rates as recommended\n")
    cat("  • Consider split applications for nitrogen\n")
    cat("  • Monitor crop response and adjust future applications\n")
    cat("  • Keep records for validation of recommendations\n")
  } else if (decision$recommendation == "APPLY_FERTILIZER_CAUTIOUSLY") {
    cat("Cautious Implementation Strategy:\n")
    cat("  • Start with 70-80% of recommended rates\n")
    cat("  • Use split applications to reduce risk\n")
    cat("  • Monitor carefully and adjust as needed\n")
    cat("  • Consider strip trials to validate response\n")
  } else if (decision$recommendation == "DO_NOT_APPLY") {
    cat("Alternative Strategy:\n")
    cat("  • Focus on improving soil data quality first\n")
    cat("  • Consider organic matter improvement\n")
    cat("  • Evaluate other limiting factors (water, pests, etc.)\n")
    cat("  • Re-evaluate after collecting better soil information\n")
  }
  
  cat("\n================================================================================\n")
  cat("                              END OF REPORT\n")
  cat("================================================================================\n\n")
}

#' Generate scenario comparison report
generate_scenario_comparison_report <- function(scenario_results) {
  
  cat("\n=== DATA QUALITY SCENARIO COMPARISON ===\n\n")
  
  # Create comparison table
  cat(sprintf("%-20s %-15s %-8s %-8s %-8s %-12s %-10s\n",
              "Scenario", "Data Quality", "N Rate", "P Rate", "K Rate", "Success %", "Risk"))
  cat(paste(rep("─", 90), collapse = ""), "\n")
  
  for (scenario_name in names(scenario_results)) {
    result <- scenario_results[[scenario_name]]
    
    cat(sprintf("%-20s %-15s %8.1f %8.1f %8.1f %11.1f %10s\n",
                scenario_name,
                result$data_quality,
                result$fertilizer_rates$N$median,
                result$fertilizer_rates$P$median,
                result$fertilizer_rates$K$median,
                result$success_probability * 100,
                substring(result$decision, 1, 10)))
  }
  
  cat("\nKey Insights:\n")
  
  # Calculate improvement from global to lab data
  if ("Global Only" %in% names(scenario_results) && "Lab Analyzed" %in% names(scenario_results)) {
    global_success <- scenario_results[["Global Only"]]$success_probability
    lab_success <- scenario_results[["Lab Analyzed"]]$success_probability
    improvement <- (lab_success - global_success) * 100
    
    cat(sprintf("• Laboratory data improves success probability by %.1f percentage points\n", improvement))
  }
  
  # Risk reduction
  global_risk <- scenario_results[["Global Only"]]$risk_score
  lab_risk <- scenario_results[["Lab Analyzed"]]$risk_score
  risk_reduction <- (global_risk - lab_risk) / global_risk * 100
  
  cat(sprintf("• Risk score reduces by %.1f%% with laboratory data\n", risk_reduction))
  
  cat("\n")
}

#' Generate yield sensitivity report
generate_yield_sensitivity_report <- function(target_results, base_target) {
  
  cat("\n=== YIELD TARGET SENSITIVITY ANALYSIS ===\n\n")
  
  cat("Effect of Different Yield Targets on Fertilizer Recommendations:\n")
  cat(sprintf("%-12s %-8s %-8s %-8s %-8s %-12s\n",
              "Target", "N Rate", "P Rate", "K Rate", "Expected", "Success %"))
  cat(paste(rep("─", 65), collapse = ""), "\n")
  
  for (target_name in names(target_results)) {
    result <- target_results[[target_name]]
    
    cat(sprintf("%-12.0f %8.1f %8.1f %8.1f %8.0f %11.1f\n",
                result$target_yield,
                result$fertilizer_rates$N,
                result$fertilizer_rates$P,
                result$fertilizer_rates$K,
                result$expected_yield,
                result$success_probability * 100))
  }
  
  cat("\nKey Observations:\n")
  
  # Find optimal target (highest success probability)
  success_probs <- sapply(target_results, function(x) x$success_probability)
  optimal_target <- names(target_results)[which.max(success_probs)]
  
  cat(sprintf("• Optimal target yield: %s kg/ha (%.1f%% success probability)\n",
              optimal_target, max(success_probs) * 100))
  
  # Economic optimum if available
  if (!all(is.na(sapply(target_results, function(x) x$economic_return)))) {
    econ_returns <- sapply(target_results, function(x) x$economic_return)
    econ_optimal <- names(target_results)[which.max(econ_returns)]
    cat(sprintf("• Economic optimum: %s kg/ha ($%.0f per hectare)\n",
                econ_optimal, max(econ_returns, na.rm = TRUE)))
  }
  
  cat("\n")
}

# ================================================================================
# 4. EXAMPLE USAGE AND DEMONSTRATIONS
# ================================================================================

#' Demonstrate the integrated system with example data
run_integrated_system_demo <- function() {
  
  cat("=== INTEGRATED DECISION SUPPORT SYSTEM DEMO ===\n\n")
  
  # Example location (Ghana)
  lat <- 7.5
  lon <- -1.5
  
  # Example field observations
  field_obs <- list(
    visual_assessment = list(
      soil_color = "dark_brown",
      texture_feel = "clay_loam",
      drainage = "well"
    ),
    field_tests = list(
      pH_strip = 6.0
    ),
    crop_history = list(
      previous_yields = c(3200, 3800, 4100),
      fertilizer_history = list(
        N = c(80, 100, 120),
        P = c(30, 40, 40),
        K = c(40, 50, 60)
      )
    )
  )
  
  # Example lab results
  lab_results <- list(
    pH = 6.2,
    organic_carbon = 18,  # g/kg
    olsen_p = 15,         # mg/kg
    exchangeable_k = 8,   # mmol/kg
    total_nitrogen = 1.8, # g/kg
    texture = list(clay = 35, sand = 40, silt = 25)
  )
  
  # Fertilizer prices
  fert_prices <- list(
    N_per_kg = 1.2,
    P_per_kg = 2.5,
    K_per_kg = 1.0,
    crop_price_per_kg = 0.30
  )
  
  # Run comprehensive analysis
  results <- comprehensive_fertilizer_recommendation(
    lat = lat,
    lon = lon,
    crop_name = "Maize",
    target_yield = 6000,
    region = "Sub-Saharan_Africa",
    field_observations = field_obs,
    lab_results = lab_results,
    fertilizer_prices = fert_prices,
    risk_tolerance = "moderate",
    n_simulations = 500
  )
  
  # Compare different data quality scenarios
  cat("\n" %R% "\nRunning scenario comparison...\n")
  scenario_comparison <- compare_data_quality_scenarios(
    lat = lat,
    lon = lon,
    crop_name = "Maize",
    target_yield = 6000,
    field_observations = field_obs,
    lab_results = lab_results,
    fertilizer_prices = fert_prices
  )
  
  return(list(
    comprehensive_results = results,
    scenario_comparison = scenario_comparison
  ))
}

cat("✓ Integrated Decision Support System loaded successfully\n")
cat("Main function: comprehensive_fertilizer_recommendation(lat, lon, crop_name, target_yield, ...)\n")
cat("Demo function: run_integrated_system_demo()\n")
cat("Comparison function: compare_data_quality_scenarios(...)\n\n")

# Fix string concatenation operator
`%R%` <- function(x, y) paste0(x, y)
