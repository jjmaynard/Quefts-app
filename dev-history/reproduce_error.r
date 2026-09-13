# Simple test to reproduce the exact error you're seeing

cat("=== REPRODUCING YOUR ERROR ===\n")

# Source the script like you did
cat("Sourcing QUEFTS-Based-Soil-Test-Calculator-Fram.r...\n")
source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")

cat("\n=== CHECKING WHAT'S LOADED ===\n")
cat("SIMULATION_MODE:", SIMULATION_MODE, "\n")

# Check if quefts_soil exists and what its signature is
if (exists("quefts_soil")) {
  cat("quefts_soil function EXISTS\n")
  cat("Function signature:\n")
  print(formals(quefts_soil))
  
  # Show the function body (first few lines)
  cat("\nFunction body (first 10 lines):\n")
  func_body <- deparse(body(quefts_soil))
  cat(paste(head(func_body, 10), collapse = "\n"))
  cat("\n...\n")
  
} else {
  cat("quefts_soil function does NOT exist\n")
}

# Now try to reproduce your exact error
cat("\n=== REPRODUCING ERROR ===\n")
cat("Creating example soil test data...\n")

example_soil <- create_soil_test(
  ph_water = 6.2,
  organic_carbon_pct = 1.8,
  olsen_p_mg_kg = 15,
  exch_k_cmol_kg = 0.8,
  total_n_pct = 0.15,
  site_name = "Test Farm Field"
)

cat("Attempting calculate_fertilizer_needs...\n")
result <- tryCatch({
  calculate_fertilizer_needs(
    soil_data = example_soil,
    crop_name = "Maize",
    target_yield_kg_ha = 6000,
    fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7)
  )
}, error = function(e) {
  cat("ERROR CAUGHT:\n")
  cat("Message:", e$message, "\n")
  cat("Call:", deparse(e$call), "\n")
  
  # This should show us exactly where and why it failed
  traceback()
  
  return(NULL)
})

if (!is.null(result)) {
  cat("SUCCESS: No error occurred!\n")
} else {
  cat("The error was reproduced.\n")
}

cat("\n=== END TEST ===\n")
