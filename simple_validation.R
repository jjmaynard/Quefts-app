# Simple validation test for uncertainty propagation methods
cat("QUEFTS Uncertainty Propagation Validation\n")
cat("==========================================\n\n")

# Check if files exist
files_to_check <- c(
  "quefts_calculation_engine.R",
  "uncertainty_quantification.R", 
  "bayesian_updating_module.R"
)

for (file in files_to_check) {
  if (file.exists(file)) {
    cat("✓", file, "exists\n")
  } else {
    cat("✗", file, "missing\n")
  }
}

cat("\nLet me try loading the main engine...\n")

# Try to load the main calculation engine
tryCatch({
  source("quefts_calculation_engine.R")
  cat("✓ QUEFTS calculation engine loaded successfully\n")
  
  # Check if key functions exist
  if (exists("calculate_fertilizer_recommendation")) {
    cat("✓ calculate_fertilizer_recommendation function available\n")
  } else {
    cat("✗ calculate_fertilizer_recommendation function missing\n")
  }
  
}, error = function(e) {
  cat("✗ Error loading QUEFTS engine:", as.character(e), "\n")
})

# Try to load uncertainty module
tryCatch({
  source("uncertainty_quantification.R")
  cat("✓ Uncertainty quantification module loaded successfully\n")
  
  if (exists("perform_sensitivity_analysis")) {
    cat("✓ perform_sensitivity_analysis function available\n")
  } else {
    cat("✗ perform_sensitivity_analysis function missing\n")
  }
  
}, error = function(e) {
  cat("✗ Error loading uncertainty module:", as.character(e), "\n")
})

# Try to load Bayesian module
tryCatch({
  source("bayesian_updating_module.R")
  cat("✓ Bayesian updating module loaded successfully\n")
  
  if (exists("bayesian_update_soil_parameters")) {
    cat("✓ bayesian_update_soil_parameters function available\n")
  } else {
    cat("✗ bayesian_update_soil_parameters function missing\n")
  }
  
  if (exists("calculate_fertilizer_recommendation_bayesian")) {
    cat("✓ calculate_fertilizer_recommendation_bayesian function available\n")
  } else {
    cat("✗ calculate_fertilizer_recommendation_bayesian function missing\n")
  }
  
}, error = function(e) {
  cat("✗ Error loading Bayesian module:", as.character(e), "\n")
})

cat("\n=== Module Loading Complete ===\n")
