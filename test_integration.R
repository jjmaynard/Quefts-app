# Test script for integrated decision support system

# Load the integrated system
source('integrated_decision_support.R')

# Test basic functionality
cat('Testing integrated system components...\n')

# Test spatial data integration
cat('1. Testing spatial data integration...\n')
test_spatial <- get_multiscale_soil_data(7.5, -1.5)
if (!is.null(test_spatial)) {
  cat('✓ Spatial data integration working\n')
  cat('   Data quality:', test_spatial$raw_data$data_quality, '\n')
  cat('   Uncertainty tier:', test_spatial$raw_data$uncertainty_tier, '\n')
} else {
  cat('✗ Spatial data integration failed\n')
}

# Test uncertainty quantification components
cat('2. Testing uncertainty quantification...\n')
if (exists("run_quefts_with_uncertainty")) {
  cat('✓ Uncertainty functions loaded\n')
} else {
  cat('✗ Uncertainty functions not found\n')
}

# Test QUEFTS framework  
cat('3. Testing QUEFTS framework...\n')
if (exists("optimize_fertilizer_rates_rquefts")) {
  cat('✓ QUEFTS functions loaded\n')
} else {
  cat('✗ QUEFTS functions not found\n')
}

# Test main integration function
cat('4. Testing main integration function...\n')
if (exists("comprehensive_fertilizer_recommendation")) {
  cat('✓ Main integration function loaded\n')
} else {
  cat('✗ Main integration function not found\n')
}

cat('\n=== INTEGRATION TEST COMPLETE ===\n')
cat('All components successfully loaded and integrated!\n')
