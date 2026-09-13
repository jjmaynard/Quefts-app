# Quick test to understand the QUEFTS situation

cat("=== DIAGNOSING QUEFTS ISSUE ===\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Check if Rquefts is available
cat("Checking for Rquefts package...\n")
rquefts_available <- requireNamespace("Rquefts", quietly = TRUE)
cat("Rquefts available:", rquefts_available, "\n")

if (rquefts_available) {
  cat("Loading Rquefts...\n")
  library(Rquefts)
  
  # List all objects in the package
  all_objects <- ls("package:Rquefts")
  cat("All objects in Rquefts package:\n")
  print(all_objects)
  
  # Look for quefts-related functions
  quefts_funcs <- all_objects[grep("quefts", all_objects, ignore.case = TRUE)]
  cat("\nQUEFTS-related functions:\n")
  print(quefts_funcs)
  
  # Check specific function signatures
  if ("quefts_soil" %in% all_objects) {
    cat("\nquefts_soil function signature:\n")
    print(formals(quefts_soil))
  } else {
    cat("\nquefts_soil function NOT found\n")
  }
  
} else {
  cat("Rquefts package is not available.\n")
  cat("Checking if any other QUEFTS-related packages are available...\n")
  
  # Check for other possible package names
  possible_packages <- c("quefts", "QUEFTS", "soilnutrient", "cropnutrient")
  for (pkg in possible_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      cat("Found package:", pkg, "\n")
    }
  }
}

# Check what functions exist in the current environment
cat("\nChecking current environment for quefts functions...\n")
all_funcs <- ls(envir = .GlobalEnv)
quefts_in_env <- all_funcs[grep("quefts", all_funcs, ignore.case = TRUE)]
cat("QUEFTS functions in environment:", paste(quefts_in_env, collapse = ", "), "\n")

# Check if there might be a function that gets loaded elsewhere
if (exists("quefts_soil")) {
  cat("\nquefts_soil function found in environment!\n")
  cat("Function arguments:\n")
  print(formals(quefts_soil))
  cat("Function body (first few lines):\n")
  print(head(deparse(body(quefts_soil)), 10))
} else {
  cat("\nquefts_soil function NOT found in current environment\n")
}

cat("\n=== END DIAGNOSIS ===\n")
