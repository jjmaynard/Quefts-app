# Simple test for SIMULATION_MODE = FALSE

options(repos = c(CRAN = "https://cran.rstudio.com/"))

cat("=== TESTING SIMULATION_MODE = FALSE ===\n")

# Load basic packages quietly
suppressMessages({
  library(dplyr)
  library(ggplot2)
})

# Check if RQuefts is available
rquefts_available <- requireNamespace("Rquefts", quietly = TRUE)
cat("RQuefts package available:", rquefts_available, "\n")

if (rquefts_available) {
  library(Rquefts)
  cat("RQuefts loaded successfully\n")
  
  # Test basic functions
  cat("Testing nutSupply1...\n")
  soil_supply <- nutSupply1(pH = 6.2, SOC = 18, Kex = 8, Polsen = 15)
  print(soil_supply)
  
  cat("Testing quefts_soil...\n")
  soil_params <- quefts_soil()
  print(names(soil_params))
  
  cat("Testing quefts_crop...\n")
  maize <- quefts_crop("Maize")
  print(names(maize))
  
  # Set SIMULATION_MODE = FALSE
  SIMULATION_MODE <- FALSE
  
  # Now test our framework functions
  cat("\n=== TESTING FRAMEWORK FUNCTIONS ===\n")
  
  # Test soil test creation
  example_soil <- list(
    site_name = "Test Site",
    pH = 6.2,
    OC = 18,  # g/kg
    Olsen_P = 15,
    Exch_K = 8,  # mmol/kg
    Total_N = 1.8
  )
  
  # Test native supply calculation with our corrected function
  source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")
  
  cat("Framework loaded with SIMULATION_MODE =", SIMULATION_MODE, "\n")
  
} else {
  cat("RQuefts package not available - cannot test SIMULATION_MODE = FALSE\n")
  cat("Install with: install.packages('Rquefts')\n")
}

cat("\n=== TEST COMPLETE ===\n")
