# Focused test with SIMULATION_MODE = FALSE

options(repos = c(CRAN = "https://cran.rstudio.com/"))

cat("=== FOCUSED RQUEFTS TEST ===\n")

# Load packages
suppressMessages({
  library(dplyr)
  library(ggplot2)
  library(Rquefts)
})

cat("✓ RQuefts version:", as.character(packageVersion('Rquefts')), "\n")

# Test basic RQuefts functionality first
cat("\n--- Testing RQuefts Functions ---\n")

# Test nutSupply1
soil_supply <- nutSupply1(pH = 6.2, SOC = 18, Kex = 8, Polsen = 15)
cat("✓ nutSupply1 works: N =", soil_supply[1,"Nsup"], "P =", soil_supply[1,"Psup"], "K =", soil_supply[1,"Ksup"], "\n")

# Test quefts_soil
soil_params <- quefts_soil()
cat("✓ quefts_soil works: Returns", length(soil_params), "parameters\n")

# Test quefts_crop
maize <- quefts_crop("Maize")
cat("✓ quefts_crop works: Returns", length(maize), "parameters\n")

# Test complete model
soil_params$N_base_supply <- soil_supply[1,"Nsup"]
soil_params$P_base_supply <- soil_supply[1,"Psup"] 
soil_params$K_base_supply <- soil_supply[1,"Ksup"]

fert <- list(N = 100, P = 50, K = 50)
biom <- list(leaf_att = 1200, stem_att = 1800, store_att = 6000, SeasonLength = 120)

q <- quefts(soil_params, maize, fert, biom)
result <- run(q)
cat("✓ Complete QUEFTS model works: Yield =", result["store_lim"], "\n")

cat("\n--- Testing Framework Integration ---\n")

# Set SIMULATION_MODE = FALSE
SIMULATION_MODE <- FALSE
cat("SIMULATION_MODE =", SIMULATION_MODE, "\n")

# Load framework
tryCatch({
  source("R/core/QUEFTS-Based-Soil-Test-Calculator-Fram.r")
  cat("✓ Framework loaded, SIMULATION_MODE =", SIMULATION_MODE, "\n")
}, error = function(e) {
  cat("✗ Framework loading error:", e$message, "\n")
})

if (!SIMULATION_MODE) {
  cat("\n--- Running Framework Test ---\n")
  
  # Create simple test
  test_soil <- list(
    site_name = "Test Field",
    pH = 6.2,
    OC = 18,  # g/kg
    Olsen_P = 15,
    Exch_K = 8,  # mmol/kg
    Total_N = 1.8
  )
  
  # Test the framework functions directly
  cat("Testing calculate_native_supply...\n")
  soil_result <- tryCatch({
    calculate_native_supply(test_soil)
  }, error = function(e) {
    cat("ERROR:", e$message, "\n")
    return(NULL)
  })
  
  if (!is.null(soil_result)) {
    cat("✓ Soil calculation success\n")
    cat("  N supply:", soil_result$N_base_supply, "\n")
    cat("  P supply:", soil_result$P_base_supply, "\n")
    cat("  K supply:", soil_result$K_base_supply, "\n")
  }
  
} else {
  cat("Framework switched to simulation mode\n")
}

cat("\n=== TEST COMPLETE ===\n")
