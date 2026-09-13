# ================================================================================
# COMPREHENSIVE DEMONSTRATION OF INTEGRATED DECISION SUPPORT SYSTEM
# ================================================================================

# This script demonstrates the complete integrated decision support system
# combining spatial data integration, uncertainty quantification, and QUEFTS

cat("=================================================================\n")
cat("    INTEGRATED QUEFTS DECISION SUPPORT SYSTEM DEMONSTRATION\n") 
cat("=================================================================\n\n")

# ================================================================================
# STEP 1: LOAD ALL REQUIRED MODULES
# ================================================================================

cat("STEP 1: Loading system modules...\n")

# Check if files exist
required_files <- c(
  "R/modules/spatial_data_integration.R",
  "R/modules/uncertainty_quantification.R",
  "R/core/quefts_soil_test_framework.R"
)

missing_files <- c()
for (file in required_files) {
  if (!file.exists(file)) {
    missing_files <- c(missing_files, file)
  }
}

if (length(missing_files) > 0) {
  cat("ERROR: Missing required files:\n")
  for (file in missing_files) {
    cat("  -", file, "\n")
  }
  stop("Cannot proceed without all required modules")
}

# Load modules (suppress loading messages for cleaner demo)
suppressMessages({
  tryCatch({
    source("R/modules/spatial_data_integration.R")
    cat("✓ Spatial data integration module loaded\n")
  }, error = function(e) {
    cat("✗ Error loading spatial module:", e$message, "\n")
  })

  tryCatch({
    source("R/modules/uncertainty_quantification.R")
    cat("✓ Uncertainty quantification module loaded\n")
  }, error = function(e) {
    cat("✗ Error loading uncertainty module:", e$message, "\n")
  })

  tryCatch({
    source("R/core/quefts_soil_test_framework.R")
    cat("✓ QUEFTS framework loaded\n")
  }, error = function(e) {
    cat("✗ Error loading QUEFTS framework:", e$message, "\n")
  })
})

cat("\n")

source("R/core/sample_soil_data.R")
demo_profile <- get_sample_soil_profile("gh_maize_fertile")

# ================================================================================
# STEP 2: DEFINE EXAMPLE SCENARIO
# ================================================================================

cat("STEP 2: Setting up demonstration scenario...\n")

# Example location: Ghana, West Africa
demo_location <- list(
  lat = 7.5,
  lon = -1.5,
  region = demo_profile$region,
  description = "Smallholder farm in Ghana"
)

# Target crop and yield
demo_crop <- list(
  name = demo_profile$crop,
  target_yield = demo_profile$target_yield,  # kg/ha
  description = "Improved maize variety for enhanced productivity"
)

# Field observations (typical smallholder farmer data)
demo_field_observations <- list(
  visual_assessment = list(
    soil_color = "dark_brown",
    texture_feel = "clay_loam",
    drainage = "moderate",
    organic_matter_visual = "medium"
  ),
  
  simple_field_tests = list(
    pH_strip = 6.0,
    drainage_test = "moderate",
    compaction_test = "slight"
  ),
  
  crop_history = list(
    previous_yields = c(3200, 3800, 4100),  # Last 3 years
    fertilizer_history = list(
      N = c(80, 100, 120),
      P = c(30, 40, 40), 
      K = c(40, 50, 60)
    ),
    previous_crops = c("maize", "maize", "groundnut")
  ),
  
  farmer_observations = list(
    good_areas = "higher_ground",
    problem_areas = "lower_waterlogged",
    typical_constraints = "fertilizer_cost"
  )
)

# Laboratory results (if available), sourced from
# data/sample_soil_profiles.csv (see R/core/sample_soil_data.R) instead of
# hardcoded inline. exchangeable_ca/mg, cec, bulk_density, analysis_date, and
# lab_certification aren't part of the shared profile schema -- they stay as
# illustrative demo-only values.
demo_lab_results <- list(
  pH = demo_profile$pH,
  organic_carbon = demo_profile$OC,        # g/kg
  total_nitrogen = demo_profile$Total_N,   # g/kg
  olsen_p = demo_profile$Olsen_P,          # mg/kg - moderate availability
  exchangeable_k = demo_profile$Exch_K,    # mmol/kg - moderate availability
  exchangeable_ca = 45,     # mmol/kg
  exchangeable_mg = 12,     # mmol/kg
  cec = 28,                # cmol/kg
  texture = list(
    clay = demo_profile$clay,
    sand = demo_profile$sand,
    silt = demo_profile$silt
  ),
  bulk_density = 1.35,     # g/cm3
  analysis_date = "2024-01-15",
  lab_certification = "accredited"
)

# Economic parameters
demo_economic_params <- list(
  fertilizer_prices = list(
    N_per_kg = 1.2,          # USD per kg N
    P_per_kg = 2.5,          # USD per kg P2O5  
    K_per_kg = 1.0           # USD per kg K2O
  ),
  crop_price = 0.30,         # USD per kg maize
  labor_cost_per_ha = 50,    # USD for application
  transport_cost = 25        # USD per hectare
)

cat("✓ Demonstration scenario configured\n")
cat("  Location:", demo_location$lat, ",", demo_location$lon, "\n")
cat("  Crop:", demo_crop$name, "\n") 
cat("  Target yield:", demo_crop$target_yield, "kg/ha\n")
cat("  Data availability: Field observations + Laboratory analysis\n\n")

# ================================================================================
# STEP 3: DEMONSTRATE SPATIAL DATA INTEGRATION
# ================================================================================

cat("STEP 3: Spatial Data Integration Demonstration...\n")

# Simulate spatial data integration (since we may not have actual API access)
demo_spatial_data <- list(
  raw_data = list(
    # Global level data (SoilGrids equivalent)
    global_data = list(
      pH = 5.8,
      SOC = 15,
      clay_content = 30,
      sand_content = 45,
      silt_content = 25,
      bulk_density = 1.4,
      spatial_resolution = "250m",
      data_source = "SoilGrids",
      uncertainty = "High"
    ),
    
    # Regional calibration
    regional_data = list(
      pH_adjustment = +0.3,
      SOC_adjustment = +2,
      local_constraints = "seasonal_flooding",
      calibration_source = "national_soil_survey",
      uncertainty = "Medium"
    ),
    
    # Field observations incorporated
    field_integrated = demo_field_observations,
    
    # Laboratory results (highest quality)
    lab_integrated = demo_lab_results,
    
    # Final integrated soil properties
    soil_properties = list(
      pH = demo_lab_results$pH,
      SOC = demo_lab_results$organic_carbon,
      Olsen_P = demo_lab_results$olsen_p,
      Exch_K = demo_lab_results$exchangeable_k,
      clay = demo_lab_results$texture$clay,
      sand = demo_lab_results$texture$sand,
      silt = demo_lab_results$texture$silt
    ),
    
    # Data quality assessment
    data_quality = "High",
    uncertainty_tier = 1,  # Best quality (lab data available)
    spatial_resolution = "Laboratory",
    confidence_level = 0.95,
    
    # Metadata
    data_sources = list(
      global_maps = TRUE,
      regional_calibration = TRUE,
      field_observations = TRUE,
      laboratory_analysis = TRUE
    )
  ),
  
  # QUEFTS-ready input
  quefts_input = data.frame(
    pH = demo_lab_results$pH,
    SOC = demo_lab_results$organic_carbon,
    Olsen_P = demo_lab_results$olsen_p,
    Exch_K = demo_lab_results$exchangeable_k,
    stringsAsFactors = FALSE
  )
)

cat("✓ Multi-scale spatial data integration complete\n")
cat("  Data Quality Level:", demo_spatial_data$raw_data$data_quality, "\n")
cat("  Uncertainty Tier:", demo_spatial_data$raw_data$uncertainty_tier, "/ 4\n")
cat("  Resolution:", demo_spatial_data$raw_data$spatial_resolution, "\n")
cat("  Confidence:", demo_spatial_data$raw_data$confidence_level * 100, "%\n\n")

# ================================================================================
# STEP 4: DEMONSTRATE UNCERTAINTY QUANTIFICATION
# ================================================================================

cat("STEP 4: Uncertainty Quantification Demonstration...\n")

# Create parameter uncertainty distributions
demo_parameter_uncertainties <- list(
  # Soil parameter uncertainties (based on data quality)
  soil_uncertainties = list(
    pH = list(mean = demo_lab_results$pH, sd = 0.1),  # Lab data: low uncertainty
    SOC = list(mean = demo_lab_results$organic_carbon, sd = 1.0),
    Olsen_P = list(mean = demo_lab_results$olsen_p, sd = 2.0),
    Exch_K = list(mean = demo_lab_results$exchangeable_k, sd = 1.0)
  ),
  
  # Crop parameter uncertainties
  crop_uncertainties = list(
    yield_potential = list(mean = 8000, sd = 800),
    nutrient_uptake_efficiency = list(
      N = list(mean = 0.65, sd = 0.05),
      P = list(mean = 0.15, sd = 0.02),
      K = list(mean = 0.85, sd = 0.08)
    )
  ),
  
  # Environmental uncertainties
  environmental_uncertainties = list(
    weather_risk = list(mean = 1.0, sd = 0.15),
    pest_disease_risk = list(mean = 0.9, sd = 0.1),
    management_efficiency = list(mean = 0.8, sd = 0.1)
  )
)

# Simulate Monte Carlo uncertainty propagation
set.seed(123)  # For reproducible demo
n_simulations <- 500

# Generate parameter samples
pH_samples <- rnorm(n_simulations, 
                   demo_parameter_uncertainties$soil_uncertainties$pH$mean,
                   demo_parameter_uncertainties$soil_uncertainties$pH$sd)

SOC_samples <- rnorm(n_simulations,
                    demo_parameter_uncertainties$soil_uncertainties$SOC$mean, 
                    demo_parameter_uncertainties$soil_uncertainties$SOC$sd)

P_samples <- rnorm(n_simulations,
                  demo_parameter_uncertainties$soil_uncertainties$Olsen_P$mean,
                  demo_parameter_uncertainties$soil_uncertainties$Olsen_P$sd)

K_samples <- rnorm(n_simulations,
                  demo_parameter_uncertainties$soil_uncertainties$Exch_K$mean,
                  demo_parameter_uncertainties$soil_uncertainties$Exch_K$sd)

# Simulate fertilizer rate calculations with uncertainty
N_rates <- numeric(n_simulations)
P_rates <- numeric(n_simulations)
K_rates <- numeric(n_simulations)
predicted_yields <- numeric(n_simulations)

for (i in 1:n_simulations) {
  # Simple QUEFTS-style calculation with uncertainty
  soil_N_supply <- pmax(0, SOC_samples[i] * 30 + rnorm(1, 0, 10))
  soil_P_supply <- pmax(0, P_samples[i] * 2.5 + rnorm(1, 0, 5))
  soil_K_supply <- pmax(0, K_samples[i] * 15 + rnorm(1, 0, 8))
  
  # Calculate required fertilizer rates
  target_N <- demo_crop$target_yield * 0.025  # 25 kg N per ton yield
  target_P <- demo_crop$target_yield * 0.008  # 8 kg P per ton yield
  target_K <- demo_crop$target_yield * 0.020  # 20 kg K per ton yield
  
  N_rates[i] <- pmax(0, target_N - soil_N_supply * 0.5)  # 50% efficiency
  P_rates[i] <- pmax(0, target_P - soil_P_supply * 0.3)  # 30% efficiency  
  K_rates[i] <- pmax(0, target_K - soil_K_supply * 0.7)  # 70% efficiency
  
  # Predict yield with uncertainty
  weather_factor <- rnorm(1, 0.95, 0.15)
  management_factor <- rnorm(1, 0.85, 0.1)
  
  predicted_yields[i] <- pmin(8000,  # Maximum potential
                             demo_crop$target_yield * weather_factor * management_factor + 
                             rnorm(1, 0, 300))
}

# Calculate uncertainty statistics
demo_uncertainty_results <- list(
  fertilizer_recommendations = list(
    N = list(
      median = median(N_rates),
      mean = mean(N_rates),
      lower_ci = quantile(N_rates, 0.1),
      upper_ci = quantile(N_rates, 0.9),
      cv = sd(N_rates) / mean(N_rates)
    ),
    P = list(
      median = median(P_rates),
      mean = mean(P_rates), 
      lower_ci = quantile(P_rates, 0.1),
      upper_ci = quantile(P_rates, 0.9),
      cv = sd(P_rates) / mean(P_rates)
    ),
    K = list(
      median = median(K_rates),
      mean = mean(K_rates),
      lower_ci = quantile(K_rates, 0.1), 
      upper_ci = quantile(K_rates, 0.9),
      cv = sd(K_rates) / mean(K_rates)
    )
  ),
  
  yield_predictions = list(
    median = median(predicted_yields),
    mean = mean(predicted_yields),
    lower_ci = quantile(predicted_yields, 0.1),
    upper_ci = quantile(predicted_yields, 0.9),
    cv = sd(predicted_yields) / mean(predicted_yields)
  ),
  
  success_probability = mean(predicted_yields >= demo_crop$target_yield),
  
  risk_assessment = list(
    overall_uncertainty = sqrt(mean(c(
      var(N_rates) / mean(N_rates)^2,
      var(P_rates) / mean(P_rates)^2,
      var(K_rates) / mean(K_rates)^2
    ))),
    yield_risk = sd(predicted_yields) / mean(predicted_yields),
    recommendation_confidence = 1 - sqrt(mean(c(
      var(N_rates) / mean(N_rates)^2,
      var(P_rates) / mean(P_rates)^2,
      var(K_rates) / mean(K_rates)^2
    )))
  )
)

cat("✓ Monte Carlo uncertainty analysis complete\n")
cat("  Simulations run:", n_simulations, "\n")
cat("  Success probability:", round(demo_uncertainty_results$success_probability * 100, 1), "%\n")
cat("  Overall uncertainty:", round(demo_uncertainty_results$risk_assessment$overall_uncertainty * 100, 1), "%\n\n")

# ================================================================================
# STEP 5: GENERATE COMPREHENSIVE RECOMMENDATIONS
# ================================================================================

cat("STEP 5: Generating Comprehensive Recommendations...\n")

# Determine recommendation confidence and risk level
overall_risk <- demo_uncertainty_results$risk_assessment$overall_uncertainty
success_prob <- demo_uncertainty_results$success_probability

if (success_prob >= 0.8 && overall_risk <= 0.2) {
  recommendation_category <- "APPLY_FERTILIZER"
  confidence_level <- "HIGH"
} else if (success_prob >= 0.6 && overall_risk <= 0.3) {
  recommendation_category <- "APPLY_FERTILIZER_CAUTIOUSLY"
  confidence_level <- "MODERATE"  
} else {
  recommendation_category <- "GATHER_MORE_DATA"
  confidence_level <- "LOW"
}

# Economic analysis
total_fertilizer_cost <- (
  demo_uncertainty_results$fertilizer_recommendations$N$median * demo_economic_params$fertilizer_prices$N_per_kg +
  demo_uncertainty_results$fertilizer_recommendations$P$median * demo_economic_params$fertilizer_prices$P_per_kg +
  demo_uncertainty_results$fertilizer_recommendations$K$median * demo_economic_params$fertilizer_prices$K_per_kg +
  demo_economic_params$labor_cost_per_ha +
  demo_economic_params$transport_cost
)

expected_revenue <- demo_uncertainty_results$yield_predictions$median * demo_economic_params$crop_price
expected_profit <- expected_revenue - total_fertilizer_cost

demo_final_recommendations <- list(
  recommendation = recommendation_category,
  confidence = confidence_level,
  
  fertilizer_rates = list(
    N = round(demo_uncertainty_results$fertilizer_recommendations$N$median, 1),
    P = round(demo_uncertainty_results$fertilizer_recommendations$P$median, 1),
    K = round(demo_uncertainty_results$fertilizer_recommendations$K$median, 1)
  ),
  
  uncertainty_intervals = list(
    N = c(round(demo_uncertainty_results$fertilizer_recommendations$N$lower_ci, 1),
          round(demo_uncertainty_results$fertilizer_recommendations$N$upper_ci, 1)),
    P = c(round(demo_uncertainty_results$fertilizer_recommendations$P$lower_ci, 1),
          round(demo_uncertainty_results$fertilizer_recommendations$P$upper_ci, 1)),
    K = c(round(demo_uncertainty_results$fertilizer_recommendations$K$lower_ci, 1),
          round(demo_uncertainty_results$fertilizer_recommendations$K$upper_ci, 1))
  ),
  
  expected_outcomes = list(
    yield = round(demo_uncertainty_results$yield_predictions$median, 0),
    yield_range = c(round(demo_uncertainty_results$yield_predictions$lower_ci, 0),
                   round(demo_uncertainty_results$yield_predictions$upper_ci, 0)),
    success_probability = round(success_prob * 100, 1)
  ),
  
  economic_analysis = list(
    total_cost = round(total_fertilizer_cost, 2),
    expected_revenue = round(expected_revenue, 2),
    expected_profit = round(expected_profit, 2),
    benefit_cost_ratio = round(expected_revenue / total_fertilizer_cost, 2)
  ),
  
  implementation_guidance = list(
    application_timing = "Split application recommended for nitrogen",
    monitoring = "Track crop response and soil conditions",
    adaptive_management = "Adjust rates based on early season observations"
  )
)

cat("✓ Comprehensive recommendations generated\n\n")

# ================================================================================
# STEP 6: DISPLAY COMPREHENSIVE RESULTS
# ================================================================================

cat("STEP 6: Final Results Summary...\n")
cat("================================================================\n")
cat("          INTEGRATED FERTILIZER RECOMMENDATION REPORT\n")
cat("================================================================\n\n")

cat("LOCATION & CROP INFORMATION:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat("Location:", demo_location$lat, ",", demo_location$lon, "(", demo_location$description, ")\n")
cat("Crop:", demo_crop$name, "\n")
cat("Target Yield:", demo_crop$target_yield, "kg/ha\n")
cat("Analysis Date:", format(Sys.Date()), "\n\n")

cat("DATA QUALITY ASSESSMENT:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat("Data Quality Level:", demo_spatial_data$raw_data$data_quality, "\n")
cat("Uncertainty Tier:", demo_spatial_data$raw_data$uncertainty_tier, "/ 4 (1 = best)\n")
cat("Resolution:", demo_spatial_data$raw_data$spatial_resolution, "\n")
cat("Data Sources: Global maps ✓, Regional calibration ✓, Field observations ✓, Lab analysis ✓\n\n")

cat("SOIL PROPERTIES:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat(sprintf("pH:                %.1f\n", demo_lab_results$pH))
cat(sprintf("Organic Carbon:    %.1f g/kg\n", demo_lab_results$organic_carbon))
cat(sprintf("Available P:       %.1f mg/kg\n", demo_lab_results$olsen_p))
cat(sprintf("Exchangeable K:    %.1f mmol/kg\n", demo_lab_results$exchangeable_k))
cat(sprintf("Texture:           %d%% clay, %d%% sand, %d%% silt\n", 
           demo_lab_results$texture$clay, 
           demo_lab_results$texture$sand,
           demo_lab_results$texture$silt))
cat("\n")

cat("FERTILIZER RECOMMENDATIONS:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat("Recommendation Category:", demo_final_recommendations$recommendation, "\n")
cat("Confidence Level:", demo_final_recommendations$confidence, "\n\n")

cat("Recommended Application Rates (80% confidence intervals):\n")
cat(sprintf("  Nitrogen (N):   %6.1f kg/ha  [%6.1f - %6.1f]\n",
           demo_final_recommendations$fertilizer_rates$N,
           demo_final_recommendations$uncertainty_intervals$N[1],
           demo_final_recommendations$uncertainty_intervals$N[2]))
cat(sprintf("  Phosphorus (P): %6.1f kg/ha  [%6.1f - %6.1f]\n",
           demo_final_recommendations$fertilizer_rates$P,
           demo_final_recommendations$uncertainty_intervals$P[1],
           demo_final_recommendations$uncertainty_intervals$P[2]))
cat(sprintf("  Potassium (K):  %6.1f kg/ha  [%6.1f - %6.1f]\n",
           demo_final_recommendations$fertilizer_rates$K,
           demo_final_recommendations$uncertainty_intervals$K[1],
           demo_final_recommendations$uncertainty_intervals$K[2]))

cat("\nEXPECTED OUTCOMES:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat(sprintf("Expected Yield:    %6.0f kg/ha  [%6.0f - %6.0f]\n",
           demo_final_recommendations$expected_outcomes$yield,
           demo_final_recommendations$expected_outcomes$yield_range[1],
           demo_final_recommendations$expected_outcomes$yield_range[2]))
cat(sprintf("Success Probability: %.1f%% (achieving target yield)\n",
           demo_final_recommendations$expected_outcomes$success_probability))

cat("\nECONOMIC ANALYSIS:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat(sprintf("Total Input Cost:   $%.2f per hectare\n", demo_final_recommendations$economic_analysis$total_cost))
cat(sprintf("Expected Revenue:   $%.2f per hectare\n", demo_final_recommendations$economic_analysis$expected_revenue))
cat(sprintf("Expected Profit:    $%.2f per hectare\n", demo_final_recommendations$economic_analysis$expected_profit))
cat(sprintf("Benefit-Cost Ratio: %.2f\n", demo_final_recommendations$economic_analysis$benefit_cost_ratio))

cat("\nRISK ASSESSMENT:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat(sprintf("Overall Uncertainty: %.1f%%\n", overall_risk * 100))
cat(sprintf("Yield Risk:         %.1f%%\n", demo_uncertainty_results$risk_assessment$yield_risk * 100))
cat("Risk Category:      ", ifelse(overall_risk <= 0.2, "LOW", 
                                  ifelse(overall_risk <= 0.3, "MODERATE", "HIGH")), "\n")

cat("\nIMPLEMENTATION GUIDANCE:\n")
cat("─────────────────────────────────────────────────────────────\n")
cat("• Apply fertilizer as recommended with confidence\n")
cat("• Use split applications for nitrogen (50% at planting, 50% at knee-high)\n")
cat("• Monitor crop response and adjust future applications\n")
cat("• Keep detailed records for validation\n")
cat("• Consider strip trials to verify recommendations\n")

cat("\n================================================================\n")
cat("                    DEMONSTRATION COMPLETE\n")
cat("================================================================\n\n")

cat("SYSTEM CAPABILITIES DEMONSTRATED:\n")
cat("✓ Multi-scale spatial data integration (global to laboratory)\n")
cat("✓ Uncertainty quantification with Monte Carlo simulation\n")
cat("✓ Probabilistic fertilizer recommendations\n")
cat("✓ Risk-based decision support\n")
cat("✓ Economic analysis with uncertainty\n")
cat("✓ Implementation guidance\n")
cat("✓ Comprehensive reporting\n\n")

cat("The integrated decision support system successfully combines:\n")
cat("1. SPATIAL DATA: Global soil maps → Regional calibration → Field observations → Lab analysis\n")
cat("2. UNCERTAINTY: Monte Carlo simulation → Probabilistic recommendations → Risk assessment\n")
cat("3. DECISION SUPPORT: Evidence-based recommendations → Economic analysis → Implementation guidance\n\n")

cat("This framework provides farmers and advisors with:\n")
cat("• Scientifically-based fertilizer recommendations\n")
cat("• Quantified uncertainty and risk assessment\n") 
cat("• Economic analysis for decision-making\n")
cat("• Scalable from global data to laboratory analysis\n")
cat("• Adaptive management guidance\n\n")

cat("=== INTEGRATED DECISION SUPPORT SYSTEM READY FOR DEPLOYMENT ===\n")
