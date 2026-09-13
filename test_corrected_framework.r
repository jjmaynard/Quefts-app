# Final test of corrected QUEFTS framework

cat("=== RUNNING CORRECTED QUEFTS FRAMEWORK ===\n\n")

# Source the corrected framework
tryCatch({
  source("QUEFTS-Based-Soil-Test-Calculator-Fram.r")
  cat("Framework loaded successfully!\n\n")
}, error = function(e) {
  cat("ERROR loading framework:", e$message, "\n")
  stop("Cannot continue")
})

cat("Current SIMULATION_MODE:", SIMULATION_MODE, "\n\n")

# Test the corrected implementation
if (!SIMULATION_MODE) {
  cat("=== TESTING WITH RQUEFTS PACKAGE ===\n")
  
  # Create example soil data
  example_soil <- create_soil_test(
    ph_water = 6.2,
    organic_carbon_pct = 1.8,
    olsen_p_mg_kg = 15,
    exch_k_cmol_kg = 0.8,
    total_n_pct = 0.15,
    site_name = "Test Farm - RQuefts Mode"
  )
  
  cat("Soil data created:\n")
  str(example_soil)
  cat("\n")
  
  # Test fertilizer calculation
  result <- tryCatch({
    calculate_fertilizer_needs(
      soil_data = example_soil,
      crop_name = "Maize",
      target_yield_kg_ha = 6000,
      fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7)
    )
  }, error = function(e) {
    cat("ERROR in fertilizer calculation:", e$message, "\n")
    traceback()
    return(NULL)
  })
  
  if (!is.null(result)) {
    cat("SUCCESS! Fertilizer calculation completed using RQuefts package.\n\n")
    
    # Generate report
    fertilizer_prices <- list(
      N_per_kg = 1.2,
      P_per_kg = 2.5,
      K_per_kg = 1.0,
      crop_price_per_kg = 0.25
    )
    
    generate_fertilizer_report(result, fertilizer_prices)
    
  } else {
    cat("Fertilizer calculation failed. Check error messages above.\n")
  }
  
} else {
  cat("Framework is running in simulation mode.\n")
  cat("To test RQuefts package, ensure SIMULATION_MODE = FALSE and RQuefts is installed.\n")
}

cat("\n=== TEST COMPLETE ===\n")
