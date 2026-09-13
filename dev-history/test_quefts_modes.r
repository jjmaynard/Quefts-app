# Test script to demonstrate QUEFTS with and without simulation mode
# This script will show the differences between simulation and full QUEFTS modes

source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")

cat("=== TESTING QUEFTS MODES ===\n\n")

# Example soil test data
example_soil <- create_soil_test(
  ph_water = 6.2,
  organic_carbon_pct = 1.8,
  olsen_p_mg_kg = 15,
  exch_k_cmol_kg = 0.8,
  total_n_pct = 0.15,
  site_name = "Test Farm Field"
)

# Test with current mode (should be FALSE now)
cat("Current SIMULATION_MODE setting:", SIMULATION_MODE, "\n\n")

if (SIMULATION_MODE) {
  cat("=== RUNNING IN SIMULATION MODE ===\n")
} else {
  cat("=== ATTEMPTING TO RUN WITH RQUEFTS PACKAGE ===\n")
  cat("Checking if Rquefts package is available...\n")
  
  # Check if Rquefts functions are available
  if (exists("quefts_soil") && exists("quefts_crop") && exists("quefts")) {
    cat("Rquefts functions found! Running with full QUEFTS functionality.\n")
  } else {
    cat("Rquefts functions NOT found. This will likely result in an error.\n")
    cat("The framework expects these functions when SIMULATION_MODE = FALSE:\n")
    cat("- quefts_soil()\n")
    cat("- quefts_crop()\n") 
    cat("- quefts()\n\n")
    
    cat("If you see errors below, this demonstrates why simulation mode is useful\n")
    cat("as a fallback when the Rquefts package is not available.\n\n")
  }
}

# Attempt to run the calculation
cat("=== RUNNING FERTILIZER CALCULATION ===\n")

tryCatch({
  # Calculate fertilizer needs
  result <- calculate_fertilizer_needs(
    soil_data = example_soil,
    crop_name = "Maize",
    target_yield_kg_ha = 6000,
    fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7)
  )
  
  cat("SUCCESS: Calculation completed!\n\n")
  
  # Generate report
  fertilizer_prices <- list(
    N_per_kg = 1.2,
    P_per_kg = 2.5,
    K_per_kg = 1.0,
    crop_price_per_kg = 0.25
  )
  
  generate_fertilizer_report(result, fertilizer_prices)
  
}, error = function(e) {
  cat("ERROR encountered during calculation:\n")
  cat("Error message:", e$message, "\n\n")
  
  cat("This error occurred because SIMULATION_MODE = FALSE but the Rquefts package\n")
  cat("is not properly installed or loaded.\n\n")
  
  cat("To fix this, either:\n")
  cat("1. Install Rquefts package: devtools::install_github('reagro/Rquefts')\n")
  cat("2. Or set SIMULATION_MODE <- TRUE in the main script\n\n")
  
  cat("=== SWITCHING TO SIMULATION MODE FOR DEMONSTRATION ===\n")
  
  # Temporarily switch to simulation mode
  SIMULATION_MODE <<- TRUE
  
  # Try again with simulation mode
  result_sim <- calculate_fertilizer_needs(
    soil_data = example_soil,
    crop_name = "Maize", 
    target_yield_kg_ha = 6000,
    fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7)
  )
  
  cat("SUCCESS: Calculation completed in simulation mode!\n\n")
  
  fertilizer_prices <- list(
    N_per_kg = 1.2,
    P_per_kg = 2.5, 
    K_per_kg = 1.0,
    crop_price_per_kg = 0.25
  )
  
  generate_fertilizer_report(result_sim, fertilizer_prices)
})

cat("\n=== MODE COMPARISON SUMMARY ===\n")
cat("SIMULATION_MODE = FALSE:\n")
cat("- Uses actual Rquefts package functions\n")
cat("- Provides research-validated QUEFTS calculations\n")
cat("- Requires Rquefts package installation\n")
cat("- More accurate for scientific applications\n\n")

cat("SIMULATION_MODE = TRUE:\n")
cat("- Uses simplified nutrient balance calculations\n")
cat("- Applies Liebig's Law of the Minimum\n")
cat("- Works without additional package dependencies\n")
cat("- Good approximation for demonstration purposes\n")
cat("- Useful fallback when Rquefts package unavailable\n")
