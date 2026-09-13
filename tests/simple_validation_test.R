# Simple validation test without package installation
cat("=== SIMPLIFIED QUEFTS FRAMEWORK VALIDATION ===\n\n")

# Try to load modules
cat("Loading QUEFTS modules...\n")

# Check if files exist first
if (file.exists("R/core/quefts_calculation_engine.R")) {
  cat("✓ Found quefts_calculation_engine.R\n")
  source("R/core/quefts_calculation_engine.R")
} else {
  cat("✗ Missing quefts_calculation_engine.R\n")
}

if (file.exists("R/modules/uncertainty_quantification.R")) {
  cat("✓ Found uncertainty_quantification.R\n")
  # Don't source this one as it tries to install packages
} else {
  cat("✗ Missing uncertainty_quantification.R\n")
}

if (file.exists("R/modules/bayesian_updating_module.R")) {
  cat("✓ Found bayesian_updating_module.R\n")
  # Try to source without installing packages
  tryCatch({
    source("R/modules/bayesian_updating_module.R")
    cat("✓ Bayesian updating module loaded\n")
  }, error = function(e) {
    cat("⚠ Bayesian updating module failed to load:", e$message, "\n")
  })
} else {
  cat("✗ Missing bayesian_updating_module.R\n")
}

# Test basic calculation if available
cat("\nTesting basic QUEFTS calculation...\n")

if (exists("calculate_fertilizer_recommendation")) {
  test_soil <- list(pH = 6.0, SOC = 20, Kex = 5, Polsen = 10)
  
  tryCatch({
    result <- calculate_fertilizer_recommendation(
      soil_data = test_soil,
      crop = "maize",
      target_yield = 5000
    )
    
    cat("✓ Basic calculation successful\n")
    cat("✓ N recommendation:", result$fertilizer_rates$N, "kg/ha\n")
    cat("✓ P recommendation:", result$fertilizer_rates$P, "kg/ha\n")
    cat("✓ K recommendation:", result$fertilizer_rates$K, "kg/ha\n")
    
  }, error = function(e) {
    cat("✗ Calculation failed:", e$message, "\n")
  })
} else {
  cat("✗ calculate_fertilizer_recommendation function not available\n")
}

cat("\n=== SIMPLE VALIDATION COMPLETE ===\n")
