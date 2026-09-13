# Test case with SIMULATION_MODE = FALSE using RQuefts package

cat("=== QUEFTS FRAMEWORK TEST WITH RQUEFTS PACKAGE ===\n")
cat("Date:", Sys.Date(), "\n")
cat("RQuefts Package: Installed and Ready\n\n")

# Set CRAN mirror and load packages
options(repos = c(CRAN = "https://cran.rstudio.com/"))
suppressMessages({
  library(dplyr)
  library(ggplot2)
  library(Rquefts)
})

cat("✓ All packages loaded successfully\n")
cat("✓ RQuefts version:", as.character(packageVersion('Rquefts')), "\n\n")

# Force SIMULATION_MODE = FALSE for this test
SIMULATION_MODE <- FALSE
cat("SIMULATION_MODE set to:", SIMULATION_MODE, "\n\n")

# Load the corrected framework
cat("=== LOADING QUEFTS FRAMEWORK ===\n")
source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")

cat("Framework loaded with SIMULATION_MODE =", SIMULATION_MODE, "\n\n")

# Create test soil data
cat("=== CREATING TEST SOIL DATA ===\n")
test_soil <- create_soil_test(
  ph_water = 6.2,
  organic_carbon_pct = 1.8,
  olsen_p_mg_kg = 15,
  exch_k_cmol_kg = 0.8,
  total_n_pct = 0.15,
  site_name = "Test Field - RQuefts Mode"
)

cat("Soil parameters:\n")
cat("  pH:", test_soil$pH, "\n")
cat("  Organic Carbon:", test_soil$OC, "g/kg\n")
cat("  Olsen P:", test_soil$Olsen_P, "mg/kg\n")
cat("  Exchangeable K:", test_soil$Exch_K, "mmol/kg\n\n")

# Test soil supply calculation
cat("=== TESTING SOIL SUPPLY CALCULATION ===\n")
soil_supply_result <- tryCatch({
  calculate_native_supply(test_soil)
}, error = function(e) {
  cat("ERROR in soil supply calculation:", e$message, "\n")
  return(NULL)
})

if (!is.null(soil_supply_result)) {
  cat("✓ Soil supply calculation successful\n")
  if (is.list(soil_supply_result) && "N_base_supply" %in% names(soil_supply_result)) {
    cat("  Native N supply:", round(soil_supply_result$N_base_supply, 1), "kg/ha\n")
    cat("  Native P supply:", round(soil_supply_result$P_base_supply, 1), "kg/ha\n")
    cat("  Native K supply:", round(soil_supply_result$K_base_supply, 1), "kg/ha\n")
  }
} else {
  cat("✗ Soil supply calculation failed\n")
}

cat("\n=== RUNNING FERTILIZER RECOMMENDATION TEST ===\n")

# Test full fertilizer calculation
fertilizer_result <- tryCatch({
  calculate_fertilizer_needs(
    soil_data = test_soil,
    crop_name = "Maize",
    target_yield_kg_ha = 6000,
    fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7)
  )
}, error = function(e) {
  cat("ERROR in fertilizer calculation:", e$message, "\n")
  cat("Error details:\n")
  print(e)
  return(NULL)
})

# Analyze and summarize results
cat("\n=== RESULTS SUMMARY ===\n")

if (!is.null(fertilizer_result)) {
  cat("✅ SUCCESS: Fertilizer calculation completed using RQuefts package!\n\n")
  
  cat("--- FERTILIZER RECOMMENDATIONS ---\n")
  cat("Nitrogen (N):", round(fertilizer_result$fertilizer_recommendation$N_kg_ha, 1), "kg/ha\n")
  cat("Phosphorus (P):", round(fertilizer_result$fertilizer_recommendation$P_kg_ha, 1), "kg/ha\n") 
  cat("Potassium (K):", round(fertilizer_result$fertilizer_recommendation$K_kg_ha, 1), "kg/ha\n")
  cat("Predicted Yield:", round(fertilizer_result$fertilizer_recommendation$predicted_yield, 0), "kg/ha\n")
  cat("Target Yield:", fertilizer_result$target_yield, "kg/ha\n\n")
  
  cat("--- NATIVE SOIL SUPPLY ---\n")
  cat("Unfertilized Yield:", round(fertilizer_result$native_supply$yield, 0), "kg/ha\n")
  cat("Native N Supply:", round(fertilizer_result$native_supply$N_supply, 1), "kg/ha\n")
  cat("Native P Supply:", round(fertilizer_result$native_supply$P_supply, 1), "kg/ha\n")
  cat("Native K Supply:", round(fertilizer_result$native_supply$K_supply, 1), "kg/ha\n\n")
  
  # Generate full report
  cat("=== GENERATING DETAILED REPORT ===\n")
  fertilizer_prices <- list(
    N_per_kg = 1.2,
    P_per_kg = 2.5,
    K_per_kg = 1.0,
    crop_price_per_kg = 0.25
  )
  
  generate_fertilizer_report(fertilizer_result, fertilizer_prices)
  
} else {
  cat("❌ FAILED: Fertilizer calculation did not complete\n")
  cat("Likely issues:\n")
  cat("- RQuefts function call problems\n")
  cat("- Parameter mismatch in corrected code\n")
  cat("- Missing biomass calculations\n\n")
  
  cat("Framework will fall back to simulation mode for reliability.\n")
}

cat("\n=== TEST COMPARISON ===\n")
cat("Mode Used:", ifelse(SIMULATION_MODE, "Simulation", "RQuefts Package"), "\n")
cat("Package Version:", ifelse(!SIMULATION_MODE, as.character(packageVersion('Rquefts')), "N/A"), "\n")
cat("Calculation Method:", ifelse(!SIMULATION_MODE, "Research-validated QUEFTS", "Simplified nutrient balance"), "\n")
cat("Status:", ifelse(!is.null(fertilizer_result), "SUCCESS", "FAILED"), "\n")

cat("\n=== END TEST ===\n")
