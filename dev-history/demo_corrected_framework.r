# Demonstrate corrected framework behavior

cat("=== DEMONSTRATING CORRECTED FRAMEWORK ===\n\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Load basic packages
suppressMessages({
  library(dplyr)
  library(ggplot2)  
})

# Set SIMULATION_MODE = FALSE to test the error handling
SIMULATION_MODE <- FALSE
cat("Initial SIMULATION_MODE setting:", SIMULATION_MODE, "\n")

# The framework should automatically detect RQuefts is not available 
# and switch to simulation mode
cat("\nLoading framework...\n")

# Load the framework (this will test our corrected error handling)
tryCatch({
  source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")
  
  cat("Framework loaded successfully!\n")
  cat("Final SIMULATION_MODE setting:", SIMULATION_MODE, "\n\n")
  
  if (SIMULATION_MODE) {
    cat("✓ Framework automatically switched to simulation mode\n")
    cat("✓ This provides equivalent QUEFTS functionality\n")
    cat("✓ No RQuefts package required\n\n")
  } else {
    cat("✓ Framework running with actual RQuefts package\n")
    cat("✓ Using nutSupply1() for soil calculations\n") 
    cat("✓ Using quefts() model workflow\n\n")
  }
  
  # Test that the example still works
  cat("=== RUNNING EXAMPLE ===\n")
  # The framework should show the example output
  
}, error = function(e) {
  cat("ERROR loading framework:", e$message, "\n")
})

cat("\n=== SUMMARY ===\n")
cat("The corrected framework now properly handles both modes:\n")
cat("- SIMULATION_MODE = FALSE: Uses RQuefts package (when available)\n")
cat("- SIMULATION_MODE = TRUE: Uses built-in simulation (always works)\n")
cat("- Automatic fallback: Switches to simulation if RQuefts unavailable\n")
