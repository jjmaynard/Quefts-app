# Simple test to show what happens with SIMULATION_MODE = FALSE

cat("=== TESTING SIMULATION_MODE = FALSE ===\n\n")

# Set simulation mode to FALSE
SIMULATION_MODE <- FALSE

cat("SIMULATION_MODE set to:", SIMULATION_MODE, "\n\n")

# Check if Rquefts package can be loaded
cat("Attempting to load Rquefts package...\n")

rquefts_available <- tryCatch({
  library(Rquefts)
  cat("SUCCESS: Rquefts package loaded successfully!\n")
  TRUE
}, error = function(e) {
  cat("ERROR: Could not load Rquefts package\n")
  cat("Error details:", e$message, "\n")
  FALSE
})

if (rquefts_available) {
  cat("\nRquefts functions that should be available:\n")
  cat("- quefts_soil():", exists("quefts_soil"), "\n")
  cat("- quefts_crop():", exists("quefts_crop"), "\n") 
  cat("- quefts():", exists("quefts"), "\n")
  
  if (exists("quefts_soil")) {
    cat("\nTesting quefts_soil() function...\n")
    
    # Try to create a soil object with the correct parameters
    test_soil <- tryCatch({
      quefts_soil(N_base_supply = 50, P_base_supply = 20, K_base_supply = 80)
    }, error = function(e) {
      cat("Error creating soil object:", e$message, "\n")
      NULL
    })
    
    if (!is.null(test_soil)) {
      cat("SUCCESS: Created QUEFTS soil object\n")
      cat("Soil object class:", class(test_soil), "\n")
    }
  }
  
} else {
  cat("\nSince Rquefts is not available, the framework would fail when\n")
  cat("SIMULATION_MODE = FALSE because it tries to call:\n")
  cat("- quefts_soil() to create soil objects\n")
  cat("- quefts_crop() to get crop parameters\n")
  cat("- quefts() to run the actual QUEFTS calculations\n\n")
  
  cat("This is why the framework has simulation mode as a fallback.\n")
  cat("To use SIMULATION_MODE = FALSE, you need to install Rquefts:\n")
  cat("devtools::install_github('reagro/Rquefts')\n")
}

cat("\n=== SUMMARY ===\n")
cat("SIMULATION_MODE = FALSE requires the Rquefts package to be installed.\n")
cat("If the package is not available, you'll get errors when trying to:\n")
cat("1. Create soil objects with quefts_soil()\n")
cat("2. Get crop parameters with quefts_crop()\n") 
cat("3. Run calculations with quefts()\n\n")
cat("The simulation mode (SIMULATION_MODE = TRUE) provides a fallback\n")
cat("that works without additional package dependencies.\n")
