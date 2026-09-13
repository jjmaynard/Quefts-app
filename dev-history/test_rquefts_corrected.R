# Test the corrected RQuefts implementation

cat("=== TESTING CORRECTED RQUEFTS IMPLEMENTATION ===\n\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Load required packages
suppressMessages({
  library(dplyr)
  library(ggplot2)
})

# Try to load RQuefts
cat("Attempting to load RQuefts package...\n")
rquefts_loaded <- tryCatch({
  library(Rquefts)
  cat("RQuefts package loaded successfully!\n")
  TRUE
}, error = function(e) {
  cat("ERROR loading RQuefts package:", e$message, "\n")
  FALSE
})

if (rquefts_loaded) {
  cat("\n=== TESTING RQUEFTS FUNCTIONS ===\n")
  
  # Test nutSupply1 function
  cat("Testing nutSupply1 function...\n")
  soil_supply <- nutSupply1(pH = 6.2, SOC = 18, Kex = 8, Polsen = 15)
  cat("Soil supply calculated:\n")
  print(soil_supply)
  
  # Test quefts_soil function
  cat("\nTesting quefts_soil function...\n")
  soil_params <- quefts_soil()
  cat("Default soil parameters:\n")
  str(soil_params)
  
  # Test quefts_crop function
  cat("\nTesting quefts_crop function...\n")
  maize_params <- quefts_crop("Maize")
  cat("Maize crop parameters:\n")
  str(maize_params)
  
  # Test complete QUEFTS model
  cat("\n=== TESTING COMPLETE QUEFTS MODEL ===\n")
  
  # Update soil with calculated supply
  soil_params$N_base_supply <- soil_supply[1, "Nsup"]
  soil_params$P_base_supply <- soil_supply[1, "Psup"]
  soil_params$K_base_supply <- soil_supply[1, "Ksup"]
  
  # Create fertilizer and biomass parameters
  fertilizer <- list(N = 100, P = 50, K = 50)
  biomass <- list(leaf_att = 1200, stem_att = 1800, store_att = 6000, SeasonLength = 120)
  
  # Create and run QUEFTS model
  q <- quefts(soil_params, maize_params, fertilizer, biomass)
  result <- run(q)
  
  cat("QUEFTS model results:\n")
  print(result)
  
  cat("\n=== SUCCESS: RQuefts functions working correctly! ===\n")
  
} else {
  cat("\nRQuefts package not available. Cannot test with SIMULATION_MODE = FALSE\n")
}

cat("\n=== END TEST ===\n")
