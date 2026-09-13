# Simple test of QUEFTS framework
cat("Starting QUEFTS test...\n")

# Source the main script
source("c:/R_Drive/Data_Files/LPKS_Data/R_Projects/QUEFTS-Based-Soil-Test-Calculator-Fram.r")

cat("Script loaded successfully!\n")

# Test basic functionality
cat("Testing basic soil test creation...\n")
test_soil <- create_soil_test(
  ph_water = 6.2,
  organic_carbon_pct = 1.8,
  olsen_p_mg_kg = 15,
  exch_k_cmol_kg = 0.8,
  site_name = "Test Field"
)

cat("Soil test created:\n")
print(test_soil)

cat("Testing fertilizer recommendation...\n")
test_rec <- calculate_fertilizer_needs(
  soil_data = test_soil,
  crop_name = "Maize",
  target_yield_kg_ha = 6000
)

cat("Basic recommendation completed!\n")
cat("Predicted yield:", test_rec$fertilizer_recommendation$predicted_yield, "kg/ha\n")

cat("Test completed successfully!\n")
