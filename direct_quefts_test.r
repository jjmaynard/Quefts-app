# Direct test of quefts_soil function

# Set CRAN mirror and load basic packages
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Try to find and load QUEFTS
cat("Looking for QUEFTS package...\n")

# Try different package names that might contain QUEFTS
possible_packages <- c("Rquefts", "quefts", "QUEFTS", "rquefts")

quefts_loaded <- FALSE
for (pkg in possible_packages) {
  cat("Trying package:", pkg, "\n")
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("Found package:", pkg, "\n")
    library(pkg, character.only = TRUE)
    quefts_loaded <- TRUE
    break
  }
}

if (!quefts_loaded) {
  cat("No QUEFTS package found. Creating mock function for testing...\n")
  
  # Create a mock function that accepts various arguments to test signatures
  quefts_soil <- function(...) {
    args <- list(...)
    arg_names <- names(args)
    cat("Mock quefts_soil called with arguments:\n")
    cat("Named arguments:", paste(arg_names, collapse = ", "), "\n")
    cat("Argument values:\n")
    print(args)
    return(list(mock = TRUE, args = args))
  }
}

# Now test the function
cat("\n=== TESTING quefts_soil FUNCTION ===\n")

if (exists("quefts_soil")) {
  cat("quefts_soil function exists!\n")
  cat("Function signature:\n")
  print(formals(quefts_soil))
  
  cat("\nTesting function call...\n")
  
  # Test with your original arguments
  result <- tryCatch({
    quefts_soil(N_base_supply = 50, P_base_supply = 20, K_base_supply = 80)
  }, error = function(e) {
    cat("Error with original arguments:", e$message, "\n")
    NULL
  })
  
  if (!is.null(result)) {
    cat("SUCCESS: Function worked with original arguments!\n")
    print(str(result))
  }
  
} else {
  cat("quefts_soil function does not exist\n")
}

cat("\n=== END TEST ===\n")
