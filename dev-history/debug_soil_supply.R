# Simple test for soil supply calculation

cat("Testing soil supply calculation...\n")

# Load packages
library(Rquefts)

# Test nutSupply1 directly
cat("Testing nutSupply1 function:\n")
soil_supply <- nutSupply1(pH = 6.2, SOC = 18, Kex = 8, Polsen = 15)
print(soil_supply)
print(str(soil_supply))

# Test column access
cat("N supply:", soil_supply[1, "N_base_supply"], "\n")
cat("P supply:", soil_supply[1, "P_base_supply"], "\n")
cat("K supply:", soil_supply[1, "K_base_supply"], "\n")

# Load framework with pre-set mode
SIMULATION_MODE <- FALSE
source('R/core/quefts_soil_test_framework.R')

cat("Framework loaded successfully\n")

# Test the calculate_native_supply function
test_soil <- list(
  site_name = "Test Field",
  pH = 6.2,
  OC = 18,
  Olsen_P = 15,
  Exch_K = 8,
  Total_N = 1.8
)

result <- calculate_native_supply(test_soil)
cat("Function result:\n")
print(result)
