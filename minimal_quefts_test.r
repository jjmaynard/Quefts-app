# Minimal test to understand what QUEFTS functions exist

cat("=== MINIMAL QUEFTS TEST ===\n")

# First, let's see what happens when we try to load our script
cat("Sourcing the main script to see what gets loaded...\n")

# Set a safe mode first
SIMULATION_MODE <- TRUE

# Source just the first part to see what packages get loaded
source("QUEFTS-Based-Soil-Test-Calculator-Fram.r")

cat("\nAfter sourcing, checking what functions exist:\n")
cat("SIMULATION_MODE:", SIMULATION_MODE, "\n")

# Check for any quefts functions
all_funcs <- ls(envir = .GlobalEnv)
quefts_funcs <- all_funcs[grep("quefts", all_funcs, ignore.case = TRUE)]
cat("QUEFTS functions in global environment:", paste(quefts_funcs, collapse = ", "), "\n")

# Check what packages are loaded
loaded_packages <- search()
cat("Loaded packages:", paste(loaded_packages, collapse = ", "), "\n")

# Look for any package with "quefts" in the name
quefts_packages <- loaded_packages[grep("quefts", loaded_packages, ignore.case = TRUE)]
cat("QUEFTS-related packages:", paste(quefts_packages, collapse = ", "), "\n")

# Try to find where quefts_soil might come from
if (exists("quefts_soil")) {
  cat("\nquefts_soil function EXISTS!\n")
  cat("Environment:", environmentName(environment(quefts_soil)), "\n")
  cat("Arguments:\n")
  print(args(quefts_soil))
} else {
  cat("\nquefts_soil function does NOT exist\n")
}

cat("\n=== END TEST ===\n")
