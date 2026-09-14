# QUEFTS-Based Soil Test Calculator Framework
# Using RQuefts package for nutrient recommendations

# Install and load required packages
# Note: Install packages if not already available
packages_needed <- c("dplyr", "ggplot2")

for (pkg in packages_needed) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

# Load standard packages
library(dplyr)
library(ggplot2)

# Load QUEFTS package (install if needed)
# Note: The actual Rquefts package may have different function signatures
# than what we initially assumed. Let's check available packages.
if (!requireNamespace("Rquefts", quietly = TRUE)) {
  # Set CRAN mirror first
  options(repos = c(CRAN = "https://cran.rstudio.com/"))

  # Rquefts is on CRAN (https://cran.r-project.org/package=Rquefts) — the
  # GitHub source formerly referenced here (reagro/Rquefts) no longer
  # resolves; install from CRAN instead.
  tryCatch({
    install.packages("Rquefts")
  }, error = function(e) {
    cat("Note: Rquefts package not available. Using simulation mode.\n")
    cat("Install manually: install.packages('Rquefts')\n")
  })
}

# Set simulation mode to FALSE to use actual RQuefts package
SIMULATION_MODE <- FALSE

# Check for enhanced calculation engine integration
ENHANCED_ENGINE_AVAILABLE <- file.exists("R/core/quefts_calculation_engine.R")

if (ENHANCED_ENGINE_AVAILABLE) {
  cat("✓ Enhanced QUEFTS Calculation Engine available for integration\n")
  cat("  Loading enhanced Monte Carlo capabilities...\n")
  suppressMessages(source("R/core/quefts_calculation_engine.R"))
  cat("✓ Enhanced engine loaded successfully\n")
} else {
  cat("Note: Enhanced calculation engine not found. Using standard framework.\n")
}

# First check if any QUEFTS-related packages are already loaded
existing_quefts <- ls(all.names = TRUE)[grep("quefts", ls(all.names = TRUE), ignore.case = TRUE)]
if (length(existing_quefts) > 0) {
  cat("Found existing QUEFTS-related objects:", paste(existing_quefts, collapse = ", "), "\n")
}

tryCatch({
  library(Rquefts)
  cat("Rquefts package loaded successfully\n")
  
  # Diagnostic information about available functions
  cat("Checking available QUEFTS functions:\n")
  all_objects <- ls("package:Rquefts")
  quefts_functions <- all_objects[grep("quefts", all_objects, ignore.case = TRUE)]
  cat("Functions with 'quefts' in name:", paste(quefts_functions, collapse = ", "), "\n")
  
  # Check specific functions we need
  if ("quefts_soil" %in% all_objects) {
    cat("quefts_soil function found\n")
    cat("Function arguments:\n")
    print(formals(quefts_soil))
    
    # (Previously called help(quefts_soil) here, which opens a browser tab
    # via R's httpd help server on every source() of this file -- disruptive
    # for anything but interactive exploration. formals() above already
    # shows the signature, so just note where to look up full docs.)
    cat("Function usage: see ?quefts_soil for full documentation\n")
  }
  if ("quefts_crop" %in% all_objects) {
    cat("quefts_crop function found\n")
  }
  if ("quefts" %in% all_objects) {
    cat("quefts function found\n")
  }
  cat("\n")
  
}, error = function(e) {
  cat("ERROR: Rquefts package not available but SIMULATION_MODE set to FALSE\n")
  cat("Install Rquefts package or set SIMULATION_MODE <- TRUE\n")
  cat("Error details:", e$message, "\n\n")
  SIMULATION_MODE <<- TRUE
})

# ==========================================
# 1. SOIL TEST DATA INPUT STRUCTURE
# ==========================================

create_soil_test <- function(ph_water, organic_carbon_pct, olsen_p_mg_kg, 
                            exch_k_cmol_kg, total_n_pct = NULL, 
                            site_name = "Default Site") {
  
  # Convert units to QUEFTS requirements
  soil_data <- list(
    site_name = site_name,
    pH = ph_water,                    # pH in water (4.5-7.0 range)
    OC = organic_carbon_pct * 10,     # Convert % to g/kg (QUEFTS uses g/kg)
    Olsen_P = olsen_p_mg_kg,          # mg/kg (should be < 30 for tropical soils)
    Exch_K = exch_k_cmol_kg * 10,     # Convert cmol/kg to mmol/kg
    Total_N = ifelse(is.null(total_n_pct), organic_carbon_pct * 0.1, total_n_pct * 10) # Estimate if not provided
  )
  
  # Validate soil data ranges
  validate_soil_data(soil_data)
  
  return(soil_data)
}

validate_soil_data <- function(soil_data) {
  warnings <- c()
  
  if (soil_data$pH < 4.5 | soil_data$pH > 7.0) {
    warnings <- c(warnings, "pH outside recommended range (4.5-7.0)")
  }
  if (soil_data$OC > 70) {
    warnings <- c(warnings, "Organic carbon > 70 g/kg (outside QUEFTS calibration)")
  }
  if (soil_data$Olsen_P > 30) {
    warnings <- c(warnings, "Olsen P > 30 mg/kg (outside original QUEFTS range)")
  }
  if (soil_data$Exch_K > 300) { # 30 mmol/kg converted
    warnings <- c(warnings, "Exchangeable K > 30 mmol/kg (outside original range)")
  }
  
  if (length(warnings) > 0) {
    cat("Validation Warnings:\n")
    for (w in warnings) {
      cat("-", w, "\n")
    }
    cat("Results may be less reliable outside calibrated ranges.\n\n")
  }
}

# ==========================================
# 2. QUEFTS SOIL SUPPLY CALCULATION
# ==========================================

calculate_native_supply <- function(soil_data) {
  
  if (SIMULATION_MODE) {
    # Simulate soil object for demonstration
    soil <- list(
      pH = soil_data$pH,
      SOC = soil_data$OC,
      Olsen_P = soil_data$Olsen_P,
      Exch_K = soil_data$Exch_K,
      season_length = 120
    )
    return(soil)
  }
  
  # Use RQuefts nutSupply1 function to calculate native soil supply
  # nutSupply1(pH, SOC, Kex, Polsen, Ptotal=NA)
  soil_supply <- nutSupply1(
    pH = soil_data$pH,
    SOC = soil_data$OC,        # Already in g/kg
    Kex = soil_data$Exch_K,    # Already in mmol/kg  
    Polsen = soil_data$Olsen_P,
    Ptotal = NA
  )
  
  # Get default soil parameters from RQuefts
  soil_params <- quefts_soil()
  
  # Update with calculated supply values
  soil_params$N_base_supply <- soil_supply[1, "N_base_supply"]  # N supply in kg/ha
  soil_params$P_base_supply <- soil_supply[1, "P_base_supply"]  # P supply in kg/ha
  soil_params$K_base_supply <- soil_supply[1, "K_base_supply"]  # K supply in kg/ha
  
  return(soil_params)
}

# ==========================================
# 3. CROP-SPECIFIC NUTRIENT CALCULATOR
# ==========================================

calculate_fertilizer_needs <- function(soil_data, crop_name, target_yield_kg_ha, 
                                      fertilizer_recovery = NULL) {
  
  # Get available crops
  available_crops <- c("Barley", "Cassava", "Chickpea", "Chillies", "Cotton", 
                      "Cowpea", "Field bean", "Groundnut", "Jute", "Kenaf", 
                      "Lentil", "Maize", "Millet (bulrush)", "Mungbean", 
                      "Onion", "Pigeonpea", "Potato", "Rapeseed", "Rice", 
                      "Sesame", "Sorghum", "Soyabean", "Sugarbeet", "Sugarcane", 
                      "Sunflower", "Sweetpotato", "Tobacco")
  
  if (!crop_name %in% available_crops) {
    stop(paste("Crop not available. Choose from:", paste(available_crops, collapse = ", ")))
  }
  
  # Create soil object
  soil <- calculate_native_supply(soil_data)
  
  # Set fertilizer recovery rates if not provided
  if (is.null(fertilizer_recovery)) {
    # Default recovery rates (can be adjusted based on local conditions)
    fertilizer_recovery <- list(N = 0.6, P = 0.2, K = 0.8)
  }
  
  if (SIMULATION_MODE) {
    # Simulate QUEFTS calculations
    results <- simulate_quefts_calculation(soil_data, crop_name, target_yield_kg_ha, fertilizer_recovery)
    return(results)
  }
  
  # Get crop parameters using RQuefts
  crop <- quefts_crop(crop_name)
  
  # Calculate biomass distribution for target yield
  # Estimate biomass distribution (this varies by crop)
  total_biomass <- target_yield_kg_ha / 0.5  # Assume grain is ~50% of total biomass
  leaf_biomass <- total_biomass * 0.2   # 20% leaves
  stem_biomass <- total_biomass * 0.3   # 30% stems  
  store_biomass <- target_yield_kg_ha   # Storage organs (grain/tuber)
  
  # Create biomass parameters
  biom <- list(
    leaf_att = leaf_biomass,
    stem_att = stem_biomass,
    store_att = store_biomass,
    SeasonLength = 120
  )
  
  # Calculate native yield (no fertilizer)
  native_fert <- list(N = 0, P = 0, K = 0)
  q_native <- quefts(soil, crop, native_fert, biom)
  native_results <- run(q_native)
  
  # Calculate fertilizer requirements iteratively
  fert_rates <- optimize_fertilizer_rates_rquefts(soil, crop, biom, target_yield_kg_ha, fertilizer_recovery, crop_name)
  
  # Calculate final recommendation with optimized fertilizer rates
  final_fert <- list(N = fert_rates["N"], P = fert_rates["P"], K = fert_rates["K"])
  q_fert <- quefts(soil, crop, final_fert, biom)
  fert_results <- run(q_fert)
  
  # Extract results
  results <- list(
    site_name = soil_data$site_name,
    crop = crop_name,
    target_yield = target_yield_kg_ha,
    native_supply = list(
      yield = native_results["store_lim"],
      N_supply = native_results["N_actual_supply"],
      P_supply = native_results["P_actual_supply"],
      K_supply = native_results["K_actual_supply"]
    ),
    fertilizer_recommendation = list(
      N_kg_ha = fert_rates["N"],
      P_kg_ha = fert_rates["P"],
      K_kg_ha = fert_rates["K"],
      predicted_yield = fert_results["store_lim"]
    ),
    nutrient_uptake = list(
      N_uptake = fert_results["N_actual_supply"] + fert_rates["N"] * fertilizer_recovery$N,
      P_uptake = fert_results["P_actual_supply"] + fert_rates["P"] * fertilizer_recovery$P,
      K_uptake = fert_results["K_actual_supply"] + fert_rates["K"] * fertilizer_recovery$K
    ),
    efficiency_ratios = calculate_efficiency_ratios_rquefts(fert_results, fert_rates)
  )
  
  return(results)
}

#' Calculate predicted yield for a soil under a FIXED fertilizer application.
#'
#' Unlike calculate_fertilizer_needs(), this does NOT re-optimize N/P/K rates
#' to hit target_yield_kg_ha -- fert_rates is applied as-is. This is what
#' sensitivity analysis needs: if fertilizer is re-optimized for every soil
#' value tested, the optimizer just compensates for the soil change and
#' yield converges back to the target regardless of the soil property being
#' varied, masking the effect we're trying to measure.
calculate_yield_with_fixed_fertilizer <- function(soil_data, crop_name, target_yield_kg_ha,
                                                  fert_rates) {

  if (SIMULATION_MODE) {
    return(simulate_yield_with_fixed_fertilizer(soil_data, crop_name, fert_rates))
  }

  soil <- calculate_native_supply(soil_data)
  crop <- quefts_crop(crop_name)

  total_biomass <- target_yield_kg_ha / 0.5
  biom <- list(
    leaf_att = total_biomass * 0.2,
    stem_att = total_biomass * 0.3,
    store_att = target_yield_kg_ha,
    SeasonLength = 120
  )

  fert <- list(N = fert_rates[["N"]], P = fert_rates[["P"]], K = fert_rates[["K"]])
  q <- quefts(soil, crop, fert, biom)
  result <- run(q)

  return(result["store_lim"])
}

# ==========================================
# SIMULATION MODE FUNCTIONS
# ==========================================

simulate_quefts_calculation <- function(soil_data, crop_name, target_yield, recovery_rates) {
  
  # Simulate native soil supply based on soil properties
  native_n_supply <- estimate_native_n_supply(soil_data$OC, soil_data$pH)
  native_p_supply <- estimate_native_p_supply(soil_data$Olsen_P)
  native_k_supply <- estimate_native_k_supply(soil_data$Exch_K)
  
  # Estimate native yield potential
  native_yield <- estimate_native_yield(native_n_supply, native_p_supply, native_k_supply, crop_name)
  
  # Calculate fertilizer needs
  fert_n <- max(0, (target_yield * get_crop_n_requirement(crop_name) - native_n_supply) / recovery_rates$N)
  fert_p <- max(0, (target_yield * get_crop_p_requirement(crop_name) - native_p_supply) / recovery_rates$P)
  fert_k <- max(0, (target_yield * get_crop_k_requirement(crop_name) - native_k_supply) / recovery_rates$K)
  
  # Estimate predicted yield with fertilizer
  total_n_supply <- native_n_supply + (fert_n * recovery_rates$N)
  total_p_supply <- native_p_supply + (fert_p * recovery_rates$P)
  total_k_supply <- native_k_supply + (fert_k * recovery_rates$K)
  
  predicted_yield <- min(target_yield * 1.1, 
                        estimate_yield_from_nutrients(total_n_supply, total_p_supply, total_k_supply, crop_name))
  
  # Simulate uptake
  n_uptake <- predicted_yield * get_crop_n_requirement(crop_name)
  p_uptake <- predicted_yield * get_crop_p_requirement(crop_name)
  k_uptake <- predicted_yield * get_crop_k_requirement(crop_name)
  
  # Create results structure
  results <- list(
    site_name = soil_data$site_name,
    crop = crop_name,
    target_yield = target_yield,
    native_supply = list(
      yield = native_yield,
      N_supply = native_n_supply,
      P_supply = native_p_supply,
      K_supply = native_k_supply
    ),
    fertilizer_recommendation = list(
      N_kg_ha = fert_n,
      P_kg_ha = fert_p,
      K_kg_ha = fert_k,
      predicted_yield = predicted_yield
    ),
    nutrient_uptake = list(
      N_uptake = n_uptake,
      P_uptake = p_uptake,
      K_uptake = k_uptake
    ),
    efficiency_ratios = list(
      nutrient_use_efficiency = list(
        N = ifelse(fert_n > 0, n_uptake / fert_n, NA),
        P = ifelse(fert_p > 0, p_uptake / fert_p, NA),
        K = ifelse(fert_k > 0, k_uptake / fert_k, NA)
      ),
      npk_ratio = paste(round(fert_n, 1), round(fert_p, 1), round(fert_k, 1), sep = ":")
    )
  )
  
  return(results)
}

#' Simulation-mode counterpart of calculate_yield_with_fixed_fertilizer():
#' applies fert_rates as-is instead of solving for the rates that hit a
#' target yield, so the resulting yield reflects the soil property change.
simulate_yield_with_fixed_fertilizer <- function(soil_data, crop_name, fert_rates,
                                                 recovery_rates = list(N = 0.6, P = 0.2, K = 0.8)) {

  native_n_supply <- estimate_native_n_supply(soil_data$OC, soil_data$pH)
  native_p_supply <- estimate_native_p_supply(soil_data$Olsen_P)
  native_k_supply <- estimate_native_k_supply(soil_data$Exch_K)

  total_n_supply <- native_n_supply + (fert_rates[["N"]] * recovery_rates$N)
  total_p_supply <- native_p_supply + (fert_rates[["P"]] * recovery_rates$P)
  total_k_supply <- native_k_supply + (fert_rates[["K"]] * recovery_rates$K)

  return(estimate_yield_from_nutrients(total_n_supply, total_p_supply, total_k_supply, crop_name))
}

# Helper functions for simulation
estimate_native_n_supply <- function(oc_g_kg, ph) {
  # Simplified N mineralization estimate
  base_n <- oc_g_kg * 0.5  # Rough estimate: 0.5 kg N per g/kg OC
  ph_factor <- ifelse(ph < 5.5, 0.7, ifelse(ph > 7.5, 0.8, 1.0))
  return(base_n * ph_factor)
}

estimate_native_p_supply <- function(olsen_p) {
  # Convert Olsen P to available P supply
  return(olsen_p * 0.5)  # Simplified conversion
}

estimate_native_k_supply <- function(exch_k_mmol_kg) {
  # Convert exchangeable K to available K supply
  return(exch_k_mmol_kg * 0.39)  # Convert mmol/kg to kg/ha (simplified)
}

get_crop_n_requirement <- function(crop_name) {
  # Nutrient requirements per 1000 kg grain equivalent
  requirements <- list(
    "Maize" = 0.025,
    "Rice" = 0.020,
    "Wheat" = 0.028,
    "Soyabean" = 0.015,  # Lower due to N fixation
    "Potato" = 0.018
  )
  return(requirements[[crop_name]] %||% 0.025)  # Default if crop not found
}

get_crop_p_requirement <- function(crop_name) {
  requirements <- list(
    "Maize" = 0.005,
    "Rice" = 0.004,
    "Wheat" = 0.005,
    "Soyabean" = 0.006,
    "Potato" = 0.003
  )
  return(requirements[[crop_name]] %||% 0.005)
}

get_crop_k_requirement <- function(crop_name) {
  requirements <- list(
    "Maize" = 0.020,
    "Rice" = 0.015,
    "Wheat" = 0.018,
    "Soyabean" = 0.022,
    "Potato" = 0.025
  )
  return(requirements[[crop_name]] %||% 0.020)
}

estimate_native_yield <- function(n_supply, p_supply, k_supply, crop_name) {
  # Liebig's law of limiting nutrients
  n_limited_yield <- n_supply / get_crop_n_requirement(crop_name)
  p_limited_yield <- p_supply / get_crop_p_requirement(crop_name)
  k_limited_yield <- k_supply / get_crop_k_requirement(crop_name)
  
  return(min(n_limited_yield, p_limited_yield, k_limited_yield))
}

estimate_yield_from_nutrients <- function(n_supply, p_supply, k_supply, crop_name) {
  # Liebig's law of limiting nutrients
  n_limited_yield <- n_supply / get_crop_n_requirement(crop_name)
  p_limited_yield <- p_supply / get_crop_p_requirement(crop_name)
  k_limited_yield <- k_supply / get_crop_k_requirement(crop_name)
  
  return(min(n_limited_yield, p_limited_yield, k_limited_yield))
}

# Null coalescing operator
`%||%` <- function(lhs, rhs) {
  if (!is.null(lhs) && length(lhs) > 0) lhs else rhs
}

# ==========================================
# 4. FERTILIZER OPTIMIZATION FUNCTION
# ==========================================

optimize_fertilizer_rates <- function(soil, crop, target_yield, recovery_rates) {
  
  if (SIMULATION_MODE) {
    # Simplified calculation for simulation mode
    base_n <- target_yield * 0.025  # ~25 kg N per 1000 kg yield
    base_p <- target_yield * 0.005  # ~5 kg P per 1000 kg yield
    base_k <- target_yield * 0.020  # ~20 kg K per 1000 kg yield
    
    # Adjust for recovery rates
    fert_n <- base_n / recovery_rates$N
    fert_p <- base_p / recovery_rates$P
    fert_k <- base_k / recovery_rates$K
    
    return(c(N = fert_n, P = fert_p, K = fert_k))
  }
  
  # Full QUEFTS optimization when package is available
  # Get crop parameters for nutrient requirements per unit yield
  crop_params <- attr(crop, "parameters")
  
  # Estimate nutrient needs (this is simplified - actual optimization would be more complex)
  base_n <- target_yield * 0.025  # ~25 kg N per 1000 kg yield (varies by crop)
  base_p <- target_yield * 0.005  # ~5 kg P per 1000 kg yield
  base_k <- target_yield * 0.020  # ~20 kg K per 1000 kg yield
  
  # Adjust for recovery rates
  fert_n <- base_n / recovery_rates$N
  fert_p <- base_p / recovery_rates$P
  fert_k <- base_k / recovery_rates$K
  
  # Simple optimization loop (in practice, use more sophisticated algorithms)
  best_rates <- c(N = fert_n, P = fert_p, K = fert_k)
  
  # Iterate to fine-tune rates
  for (i in 1:10) {
    test_result <- quefts(soil, crop, fertilizer = best_rates)
    
    if (abs(test_result$yield - target_yield) < target_yield * 0.05) {
      break  # Within 5% of target
    }
    
    # Adjust rates based on yield gap
    yield_ratio <- target_yield / test_result$yield
    if (yield_ratio > 1.05) {
      best_rates <- best_rates * min(1.2, yield_ratio * 0.8)
    } else if (yield_ratio < 0.95) {
      best_rates <- best_rates * max(0.8, yield_ratio * 1.1)
    }
  }
  
  return(best_rates)
}

# RQuefts-specific optimization function
optimize_fertilizer_rates_rquefts <- function(soil, crop, biom, target_yield, recovery_rates, crop_name) {

  # Initial estimate: crop uptake needed for the target yield, MINUS what the
  # soil already supplies natively, divided by recovery rate. Using a
  # soil-blind guess here (e.g. flat target_yield * 0.025 / recovery$N) was
  # generous enough to satisfy the 5% convergence check below on the first
  # pass for most realistic soils, regardless of native fertility -- so the
  # loop never got far enough to differentiate one site from another and
  # recommendations came out nearly identical across very different soils.
  native_n <- soil$N_base_supply %||% 0
  native_p <- soil$P_base_supply %||% 0
  native_k <- soil$K_base_supply %||% 0

  n_rate <- max(0, (target_yield * get_crop_n_requirement(crop_name) - native_n) / recovery_rates$N)
  p_rate <- max(0, (target_yield * get_crop_p_requirement(crop_name) - native_p) / recovery_rates$P)
  k_rate <- max(0, (target_yield * get_crop_k_requirement(crop_name) - native_k) / recovery_rates$K)

  best_rates <- c(N = n_rate, P = p_rate, K = k_rate)

  # Simple optimization - try different combinations
  for (i in 1:10) {
    # Test current rates
    test_fert <- list(N = best_rates["N"], P = best_rates["P"], K = best_rates["K"])
    q <- quefts(soil, crop, test_fert, biom)
    result <- run(q)

    predicted_yield <- result["store_lim"]
    yield_diff <- abs(predicted_yield - target_yield)

    # If close enough, stop
    if (yield_diff < target_yield * 0.05) {
      break
    }

    # Adjust each nutrient independently by how far ITS OWN actual supply
    # (native + fertilizer*recovery) is from the crop's requirement, rather
    # than scaling N, P and K together by one yield-derived ratio -- a
    # nutrient that's already abundant in the soil shouldn't keep getting
    # scaled up just because another nutrient is limiting overall yield.
    actual_supply <- c(
      N = result[["N_supply"]],
      P = result[["P_supply"]],
      K = result[["K_supply"]]
    )
    required_supply <- c(
      N = target_yield * get_crop_n_requirement(crop_name),
      P = target_yield * get_crop_p_requirement(crop_name),
      K = target_yield * get_crop_k_requirement(crop_name)
    )
    supply_ratio <- required_supply / pmax(actual_supply, 1e-6)
    adjustment <- pmin(1.3, pmax(0.7, supply_ratio))

    # NOTE: pmax()/pmin() silently drop the names() attribute of their
    # arguments (a base-R quirk -- unlike `*`, which keeps the first
    # operand's names). best_rates["N"] on an unnamed vector returns NA,
    # which then poisons every later quefts() call in this loop. Clamp with
    # plain indexing instead so N/P/K names survive.
    best_rates <- best_rates * adjustment
    best_rates[best_rates < 0] <- 0
  }

  return(best_rates)
}

# ==========================================
# 5. EFFICIENCY AND ECONOMIC CALCULATIONS
# ==========================================

calculate_efficiency_ratios <- function(recommendation, fertilizer_rates) {
  
  # Nutrient use efficiency calculations
  nue_n <- ifelse(fertilizer_rates["N"] > 0, 
                  recommendation$N_uptake / fertilizer_rates["N"], NA)
  nue_p <- ifelse(fertilizer_rates["P"] > 0, 
                  recommendation$P_uptake / fertilizer_rates["P"], NA)
  nue_k <- ifelse(fertilizer_rates["K"] > 0, 
                  recommendation$K_uptake / fertilizer_rates["K"], NA)
  
  # Agronomic efficiency (yield increase per unit fertilizer)
  # This would require baseline yield calculation
  
  return(list(
    nutrient_use_efficiency = list(N = nue_n, P = nue_p, K = nue_k),
    npk_ratio = paste(round(fertilizer_rates["N"], 1), 
                     round(fertilizer_rates["P"], 1), 
                     round(fertilizer_rates["K"], 1), sep = ":")
  ))
}

# RQuefts-specific efficiency calculation
calculate_efficiency_ratios_rquefts <- function(rquefts_results, fertilizer_rates) {
  
  # Extract uptake values from RQuefts results
  n_uptake <- rquefts_results["N_actual_supply"]
  p_uptake <- rquefts_results["P_actual_supply"] 
  k_uptake <- rquefts_results["K_actual_supply"]
  
  # Nutrient use efficiency calculations
  nue_n <- ifelse(fertilizer_rates["N"] > 0, n_uptake / fertilizer_rates["N"], NA)
  nue_p <- ifelse(fertilizer_rates["P"] > 0, p_uptake / fertilizer_rates["P"], NA)
  nue_k <- ifelse(fertilizer_rates["K"] > 0, k_uptake / fertilizer_rates["K"], NA)
  
  return(list(
    nutrient_use_efficiency = list(N = nue_n, P = nue_p, K = nue_k),
    npk_ratio = paste(round(fertilizer_rates["N"], 1), 
                     round(fertilizer_rates["P"], 1), 
                     round(fertilizer_rates["K"], 1), sep = ":")
  ))
}

# ==========================================
# 6. REPORT GENERATION FUNCTION
# ==========================================

generate_fertilizer_report <- function(results, fertilizer_prices = NULL) {
  
  cat("=== QUEFTS FERTILIZER RECOMMENDATION REPORT ===\n")
  cat("Site:", results$site_name, "\n")
  cat("Crop:", results$crop, "\n")
  cat("Target Yield:", results$target_yield, "kg/ha\n\n")
  
  cat("--- NATIVE SOIL SUPPLY ---\n")
  cat("Unfertilized Yield Potential:", round(results$native_supply$yield, 0), "kg/ha\n")
  cat("Native N Supply:", round(results$native_supply$N_supply, 1), "kg/ha\n")
  cat("Native P Supply:", round(results$native_supply$P_supply, 1), "kg/ha\n")
  cat("Native K Supply:", round(results$native_supply$K_supply, 1), "kg/ha\n\n")
  
  cat("--- FERTILIZER RECOMMENDATIONS ---\n")
  cat("Nitrogen (N):", round(results$fertilizer_recommendation$N_kg_ha, 1), "kg/ha\n")
  cat("Phosphorus (P):", round(results$fertilizer_recommendation$P_kg_ha, 1), "kg/ha\n")
  cat("Potassium (K):", round(results$fertilizer_recommendation$K_kg_ha, 1), "kg/ha\n")
  cat("NPK Ratio:", results$efficiency_ratios$npk_ratio, "\n")
  cat("Predicted Yield:", round(results$fertilizer_recommendation$predicted_yield, 0), "kg/ha\n\n")
  
  cat("--- NUTRIENT USE EFFICIENCY ---\n")
  if (!is.na(results$efficiency_ratios$nutrient_use_efficiency$N)) {
    cat("N Use Efficiency:", round(results$efficiency_ratios$nutrient_use_efficiency$N, 2), "\n")
  }
  if (!is.na(results$efficiency_ratios$nutrient_use_efficiency$P)) {
    cat("P Use Efficiency:", round(results$efficiency_ratios$nutrient_use_efficiency$P, 2), "\n")
  }
  if (!is.na(results$efficiency_ratios$nutrient_use_efficiency$K)) {
    cat("K Use Efficiency:", round(results$efficiency_ratios$nutrient_use_efficiency$K, 2), "\n")
  }
  
  # Economic analysis if prices provided
  if (!is.null(fertilizer_prices)) {
    cat("\n--- ECONOMIC ANALYSIS ---\n")
    total_cost <- (results$fertilizer_recommendation$N_kg_ha * fertilizer_prices$N_per_kg +
                   results$fertilizer_recommendation$P_kg_ha * fertilizer_prices$P_per_kg +
                   results$fertilizer_recommendation$K_kg_ha * fertilizer_prices$K_per_kg)
    cat("Total Fertilizer Cost:", round(total_cost, 2), "per hectare\n")
    
    if (!is.null(fertilizer_prices$crop_price_per_kg)) {
      yield_increase <- results$fertilizer_recommendation$predicted_yield - results$native_supply$yield
      revenue_increase <- yield_increase * fertilizer_prices$crop_price_per_kg
      net_benefit <- revenue_increase - total_cost
      cat("Additional Revenue:", round(revenue_increase, 2), "\n")
      cat("Net Benefit:", round(net_benefit, 2), "\n")
      cat("Benefit:Cost Ratio:", round(revenue_increase / total_cost, 2), "\n")
    }
  }
}

# ==========================================
# 7. EXAMPLE USAGE AND DEMONSTRATION
# ==========================================

# Example soil test data
example_soil <- create_soil_test(
  ph_water = 6.2,
  organic_carbon_pct = 1.8,
  olsen_p_mg_kg = 15,
  exch_k_cmol_kg = 0.8,
  total_n_pct = 0.15,
  site_name = "Farm Field A"
)

# Example calculation for maize
maize_recommendation <- calculate_fertilizer_needs(
  soil_data = example_soil,
  crop_name = "Maize",
  target_yield_kg_ha = 6000,
  fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7)
)

# Generate report
fertilizer_prices <- list(
  N_per_kg = 1.2,    # Price per kg N
  P_per_kg = 2.5,    # Price per kg P
  K_per_kg = 1.0,    # Price per kg K
  crop_price_per_kg = 0.25  # Maize price per kg
)

generate_fertilizer_report(maize_recommendation, fertilizer_prices)

# ==========================================
# 8. BATCH PROCESSING FUNCTION
# ==========================================

process_multiple_fields <- function(soil_test_data, crop_name, target_yield) {
  
  results_list <- list()
  
  for (i in 1:nrow(soil_test_data)) {
    soil <- create_soil_test(
      ph_water = soil_test_data$pH[i],
      organic_carbon_pct = soil_test_data$OC_pct[i],
      olsen_p_mg_kg = soil_test_data$Olsen_P[i],
      exch_k_cmol_kg = soil_test_data$Exch_K[i],
      site_name = soil_test_data$field_name[i]
    )
    
    results_list[[i]] <- calculate_fertilizer_needs(soil, crop_name, target_yield)
  }
  
  return(results_list)
}

# ==========================================
# 9. EXPECTED LOSS AND UNCERTAINTY MODELING
# ==========================================

# Define yield uncertainty parameters
get_yield_uncertainty <- function(predicted_yield, uncertainty_factor = 0.15) {
  # Default uncertainty is 15% of predicted yield
  yield_sd <- predicted_yield * uncertainty_factor
  return(list(mean = predicted_yield, sd = yield_sd))
}

# Calculate expected loss for fertilizer recommendation
calculate_expected_loss <- function(results, fertilizer_prices, 
                                   yield_uncertainty_factor = 0.15,
                                   price_uncertainty = NULL,
                                   n_simulations = 10000) {
  
  # Extract key values
  predicted_yield_fert <- results$fertilizer_recommendation$predicted_yield
  native_yield <- results$native_supply$yield
  
  # Calculate fertilizer cost
  fert_cost <- (results$fertilizer_recommendation$N_kg_ha * fertilizer_prices$N_per_kg +
                results$fertilizer_recommendation$P_kg_ha * fertilizer_prices$P_per_kg +
                results$fertilizer_recommendation$K_kg_ha * fertilizer_prices$K_per_kg)
  
  # Define yield uncertainty
  yield_fert_params <- get_yield_uncertainty(predicted_yield_fert, yield_uncertainty_factor)
  yield_native_params <- get_yield_uncertainty(native_yield, yield_uncertainty_factor)
  
  # Price uncertainty (if specified)
  if (is.null(price_uncertainty)) {
    crop_price_mean <- fertilizer_prices$crop_price_per_kg
    crop_price_sd <- 0
  } else {
    crop_price_mean <- fertilizer_prices$crop_price_per_kg
    crop_price_sd <- crop_price_mean * price_uncertainty$crop_price_cv
  }
  
  # Monte Carlo simulation
  set.seed(123)
  
  # Simulate yields and prices
  yield_fert_sim <- rnorm(n_simulations, yield_fert_params$mean, yield_fert_params$sd)
  yield_native_sim <- rnorm(n_simulations, yield_native_params$mean, yield_native_params$sd)
  
  if (crop_price_sd > 0) {
    crop_price_sim <- rnorm(n_simulations, crop_price_mean, crop_price_sd)
  } else {
    crop_price_sim <- rep(crop_price_mean, n_simulations)
  }
  
  # Calculate net benefits for each scenario
  net_benefit_fert <- (yield_fert_sim * crop_price_sim) - fert_cost
  net_benefit_native <- yield_native_sim * crop_price_sim
  
  # Calculate losses (negative net benefit)
  loss_act <- -net_benefit_fert  # Loss from applying fertilizer
  loss_no_act <- -net_benefit_native  # Loss from not applying fertilizer
  
  # Expected losses
  expected_loss_act <- mean(loss_act)
  expected_loss_no_act <- mean(loss_no_act)
  
  # Risk metrics
  var_loss_act <- var(loss_act)
  var_loss_no_act <- var(loss_no_act)
  
  # Value at Risk (VaR) - 95th percentile loss
  var_95_act <- quantile(loss_act, 0.95)
  var_95_no_act <- quantile(loss_no_act, 0.95)
  
  # Probability of loss
  prob_loss_act <- mean(loss_act > 0)
  prob_loss_no_act <- mean(loss_no_act > 0)
  
  return(list(
    expected_loss_act = expected_loss_act,
    expected_loss_no_act = expected_loss_no_act,
    decision = ifelse(expected_loss_act < expected_loss_no_act, "Apply fertilizer", "Do not apply fertilizer"),
    risk_metrics = list(
      variance_loss_act = var_loss_act,
      variance_loss_no_act = var_loss_no_act,
      var_95_act = var_95_act,
      var_95_no_act = var_95_no_act,
      prob_loss_act = prob_loss_act,
      prob_loss_no_act = prob_loss_no_act
    ),
    simulation_results = list(
      loss_act = loss_act,
      loss_no_act = loss_no_act,
      net_benefit_fert = net_benefit_fert,
      net_benefit_native = net_benefit_native
    )
  ))
}

# Enhanced fertilizer recommendation with expected loss
calculate_fertilizer_needs_with_uncertainty <- function(soil_data, crop_name, target_yield_kg_ha, 
                                                       fertilizer_recovery = NULL,
                                                       fertilizer_prices = NULL,
                                                       yield_uncertainty_factor = 0.15,
                                                       price_uncertainty = NULL) {
  
  # Get basic QUEFTS recommendation
  basic_results <- calculate_fertilizer_needs(soil_data, crop_name, target_yield_kg_ha, fertilizer_recovery)
  
  # If no prices provided, return basic results
  if (is.null(fertilizer_prices)) {
    return(basic_results)
  }
  
  # Calculate expected loss analysis
  loss_analysis <- calculate_expected_loss(basic_results, fertilizer_prices, 
                                          yield_uncertainty_factor, price_uncertainty)
  
  # Add uncertainty analysis to results
  basic_results$uncertainty_analysis <- loss_analysis
  
  return(basic_results)
}

# Generate enhanced report with uncertainty analysis
generate_enhanced_fertilizer_report <- function(results, include_uncertainty = TRUE) {
  
  # Generate basic report
  if (!is.null(results$uncertainty_analysis)) {
    fertilizer_prices <- list(
      N_per_kg = 1.2, P_per_kg = 2.5, K_per_kg = 1.0, crop_price_per_kg = 0.25
    )
    generate_fertilizer_report(results, fertilizer_prices)
  } else {
    generate_fertilizer_report(results)
  }
  
  # Add uncertainty analysis if available
  if (include_uncertainty && !is.null(results$uncertainty_analysis)) {
    ua <- results$uncertainty_analysis
    
    cat("\n=== UNCERTAINTY AND RISK ANALYSIS ===\n")
    cat("Expected Loss if Acting (Apply Fertilizer):", round(ua$expected_loss_act, 2), "\n")
    cat("Expected Loss if Not Acting (No Fertilizer):", round(ua$expected_loss_no_act, 2), "\n")
    cat("Recommended Decision:", ua$decision, "\n\n")
    
    cat("--- RISK METRICS ---\n")
    cat("Probability of Loss (Acting):", round(ua$risk_metrics$prob_loss_act, 3), "\n")
    cat("Probability of Loss (Not Acting):", round(ua$risk_metrics$prob_loss_no_act, 3), "\n")
    cat("95% Value at Risk (Acting):", round(ua$risk_metrics$var_95_act, 2), "\n")
    cat("95% Value at Risk (Not Acting):", round(ua$risk_metrics$var_95_no_act, 2), "\n")
    
    # Risk preference guidance
    loss_diff <- ua$expected_loss_no_act - ua$expected_loss_act
    if (loss_diff > 50) {
      cat("\nRisk Assessment: Strong economic case for fertilizer application\n")
    } else if (loss_diff > 0) {
      cat("\nRisk Assessment: Moderate economic case for fertilizer application\n")
    } else {
      cat("\nRisk Assessment: Economic case against fertilizer application\n")
    }
  }
}

# Sensitivity analysis function (to assumed uncertainty LEVEL, not soil
# parameters -- renamed from the original perform_sensitivity_analysis to
# stop it silently shadowing uncertainty_quantification.R's function of the
# same name, which does per-parameter sensitivity and is what
# integrated_decision_support.R and bayesian_updating_module.R actually call.
# This function itself has no callers anywhere in the project.)
perform_uncertainty_level_sensitivity_analysis <- function(soil_data, crop_name, target_yield_kg_ha,
                                       fertilizer_prices, base_uncertainty = 0.15) {
  
  uncertainty_levels <- c(0.05, 0.10, 0.15, 0.20, 0.25, 0.30)
  results_list <- list()
  
  for (i in seq_along(uncertainty_levels)) {
    results <- calculate_fertilizer_needs_with_uncertainty(
      soil_data, crop_name, target_yield_kg_ha,
      fertilizer_prices = fertilizer_prices,
      yield_uncertainty_factor = uncertainty_levels[i]
    )
    
    results_list[[i]] <- list(
      uncertainty_level = uncertainty_levels[i],
      expected_loss_act = results$uncertainty_analysis$expected_loss_act,
      expected_loss_no_act = results$uncertainty_analysis$expected_loss_no_act,
      decision = results$uncertainty_analysis$decision
    )
  }
  
  return(results_list)
}

# ==========================================
# 10. VISUALIZATION FUNCTIONS
# ==========================================

plot_yield_response <- function(soil_data, crop_name, max_n = 200) {
  
  soil <- calculate_native_supply(soil_data)
  
  n_rates <- seq(0, max_n, by = 20)
  yields <- numeric(length(n_rates))
  
  if (SIMULATION_MODE) {
    # Simulate yield response curve
    native_yield <- estimate_native_yield(
      estimate_native_n_supply(soil_data$OC, soil_data$pH),
      estimate_native_p_supply(soil_data$Olsen_P),
      estimate_native_k_supply(soil_data$Exch_K),
      crop_name
    )
    
    for (i in seq_along(n_rates)) {
      # Simulate diminishing returns to N fertilizer
      n_effect <- n_rates[i] * 0.6  # Assume 60% recovery
      max_response <- native_yield * 2.5  # Maximum possible with N
      yields[i] <- native_yield + (max_response - native_yield) * (1 - exp(-n_effect / 100))
    }
  } else {
    # Use actual QUEFTS model
    crop <- quefts_crop(crop_name)
    
    for (i in seq_along(n_rates)) {
      result <- quefts(soil, crop, fertilizer = c(N = n_rates[i], P = 0, K = 0))
      yields[i] <- result$yield
    }
  }
  
  df <- data.frame(N_rate = n_rates, Yield = yields)
  
  ggplot(df, aes(x = N_rate, y = Yield)) +
    geom_line(color = "blue", size = 1) +
    geom_point(color = "red", size = 2) +
    labs(title = paste("Nitrogen Response Curve for", crop_name),
         subtitle = ifelse(SIMULATION_MODE, "(Simulation Mode)", "(QUEFTS Model)"),
         x = "Nitrogen Rate (kg/ha)",
         y = "Yield (kg/ha)") +
    theme_minimal()
}

# Plot uncertainty analysis results
plot_uncertainty_analysis <- function(results) {
  
  if (is.null(results$uncertainty_analysis)) {
    stop("No uncertainty analysis found in results. Run calculate_fertilizer_needs_with_uncertainty() first.")
  }
  
  ua <- results$uncertainty_analysis
  sim_results <- ua$simulation_results
  
  # Create data frame for plotting
  plot_data <- data.frame(
    scenario = rep(c("With Fertilizer", "Without Fertilizer"), each = length(sim_results$net_benefit_fert)),
    net_benefit = c(sim_results$net_benefit_fert, sim_results$net_benefit_native)
  )
  
  # Plot distribution of net benefits
  p1 <- ggplot(plot_data, aes(x = net_benefit, fill = scenario)) +
    geom_histogram(alpha = 0.7, bins = 50, position = "identity") +
    geom_vline(data = data.frame(
      scenario = c("With Fertilizer", "Without Fertilizer"),
      mean_benefit = c(mean(sim_results$net_benefit_fert), mean(sim_results$net_benefit_native))
    ), aes(xintercept = mean_benefit), linetype = "dashed", color = "black") +
    facet_wrap(~scenario, scales = "free_y") +
    labs(title = "Distribution of Net Benefits",
         x = "Net Benefit ($/ha)",
         y = "Frequency") +
    theme_minimal() +
    theme(legend.position = "none")
  
  return(p1)
}

cat("\n=== QUEFTS SOIL TEST CALCULATOR FRAMEWORK LOADED ===\n")
cat("Key functions available:\n")
cat("- create_soil_test(): Input soil test data\n")
cat("- calculate_fertilizer_needs(): Generate recommendations\n")
cat("- calculate_fertilizer_needs_with_uncertainty(): Generate recommendations with uncertainty analysis\n")
cat("- calculate_fertilizer_needs_enhanced(): Enhanced Monte Carlo recommendations (if engine available)\n")
cat("- generate_fertilizer_report(): Create detailed reports\n")
cat("- generate_enhanced_fertilizer_report(): Create reports with uncertainty analysis\n")
cat("- generate_enhanced_monte_carlo_report(): Create Monte Carlo reports (if engine available)\n")
cat("- plot_yield_response(): Visualize nutrient response\n")
cat("- plot_uncertainty_analysis(): Visualize uncertainty in net benefits\n")
cat("- process_multiple_fields(): Batch processing\n")
cat("- demo_enhanced_integration(): Demonstrate enhanced engine integration\n\n")

if (ENHANCED_ENGINE_AVAILABLE) {
  cat("✓ Enhanced Monte Carlo QUEFTS Calculation Engine is AVAILABLE\n")
  cat("  Enhanced functions provide:\n")
  cat("  • Monte Carlo uncertainty propagation (up to 1000+ simulations)\n")
  cat("  • Confidence intervals for all recommendations\n")
  cat("  • Probabilistic success rates\n")
  cat("  • Economic risk assessment\n")
  cat("  • Comprehensive uncertainty quantification\n\n")
} else {
  cat("Note: Enhanced Monte Carlo engine not available. Using standard framework.\n")
  cat("      Place 'quefts_calculation_engine.R' in same directory for enhanced capabilities.\n\n")
}

cat("Example usage:\n")
cat("soil <- create_soil_test(6.2, 1.8, 15, 0.8, site_name='Field 1')\n")
cat("rec <- calculate_fertilizer_needs(soil, 'Maize', 6000)\n")
cat("generate_fertilizer_report(rec)\n\n")

cat("Example with uncertainty analysis:\n")
cat("prices <- list(N_per_kg=1.2, P_per_kg=2.5, K_per_kg=1.0, crop_price_per_kg=0.25)\n")
cat("rec_uncertain <- calculate_fertilizer_needs_with_uncertainty(soil, 'Maize', 6000, fertilizer_prices=prices)\n")
cat("generate_enhanced_fertilizer_report(rec_uncertain)\n\n")

if (ENHANCED_ENGINE_AVAILABLE) {
  cat("Example with enhanced Monte Carlo analysis:\n")
  cat("rec_enhanced <- calculate_fertilizer_needs_enhanced(soil, 'Maize', 6000, uncertainty_level='medium')\n")
  cat("generate_enhanced_monte_carlo_report(rec_enhanced)\n")
  cat("demo_enhanced_integration()  # Run complete demonstration\n\n")
}

# ==========================================
# 11. ENHANCED EXAMPLE WITH UNCERTAINTY
# ==========================================

# Example with uncertainty analysis
cat("\n=== RUNNING ENHANCED EXAMPLE WITH UNCERTAINTY ANALYSIS ===\n")

# Enhanced calculation with uncertainty
maize_recommendation_uncertain <- calculate_fertilizer_needs_with_uncertainty(
  soil_data = example_soil,
  crop_name = "Maize",
  target_yield_kg_ha = 6000,
  fertilizer_recovery = list(N = 0.6, P = 0.2, K = 0.7),
  fertilizer_prices = fertilizer_prices,
  yield_uncertainty_factor = 0.15  # 15% yield uncertainty
)

# Generate enhanced report
generate_enhanced_fertilizer_report(maize_recommendation_uncertain)

# ==========================================
# 12. ENHANCED CALCULATION ENGINE INTEGRATION
# ==========================================

#' Enhanced fertilizer recommendation using Monte Carlo QUEFTS engine
#' 
#' This function integrates the existing framework with the enhanced calculation engine
#' for comprehensive uncertainty quantification and Monte Carlo simulation
#' 
#' @param soil_test Soil test object from create_soil_test()
#' @param crop_name Target crop name
#' @param target_yield Target yield (kg/ha)
#' @param uncertainty_level Uncertainty level ("low", "medium", "high")
#' @param economic_params Economic parameters for cost-benefit analysis
#' @param n_simulations Number of Monte Carlo simulations
#' @return Enhanced results with comprehensive uncertainty analysis
calculate_fertilizer_needs_enhanced <- function(soil_test, crop_name, target_yield,
                                               uncertainty_level = "medium",
                                               economic_params = NULL,
                                               n_simulations = 1000) {
  
  cat("=== ENHANCED FERTILIZER RECOMMENDATION CALCULATION ===\n")
  
  # Check if enhanced engine is available
  if (!exists("calculate_fertilizer_recommendation")) {
    cat("Enhanced calculation engine not available. Using standard framework.\n")
    return(calculate_fertilizer_needs_with_uncertainty(
      soil_test, crop_name, target_yield
    ))
  }
  
  # Convert soil test object to enhanced engine format
  soil_data_enhanced <- list(
    pH = soil_test$pH,
    SOC = soil_test$SOC * 10,  # Convert % to g/kg
    Kex = soil_test$Exch_K * 10,  # Convert cmol/kg to mmol/kg (approximate)
    Polsen = soil_test$Olsen_P
  )
  
  cat("Converted soil data for enhanced engine:\n")
  cat("  pH:", soil_data_enhanced$pH, "\n")
  cat("  SOC:", soil_data_enhanced$SOC, "g/kg\n")
  cat("  Exchangeable K:", soil_data_enhanced$Kex, "mmol/kg\n")
  cat("  Olsen P:", soil_data_enhanced$Polsen, "mg/kg\n\n")
  
  # Set up economic parameters if not provided
  if (is.null(economic_params)) {
    economic_params <- list(
      N_price = list(mean = 1.2, sd = 0.15),
      P_price = list(mean = 2.5, sd = 0.30),
      K_price = list(mean = 1.0, sd = 0.12),
      crop_price = list(mean = 0.30, sd = 0.03),
      application_cost = list(mean = 25, sd = 5)
    )
  }
  
  # Run enhanced calculation
  enhanced_result <- calculate_fertilizer_recommendation(
    soil_data = soil_data_enhanced,
    crop = crop_name,
    target_yield = target_yield,
    uncertainty_level = uncertainty_level,
    economic_params = economic_params,
    n_simulations = n_simulations
  )
  
  # Convert results back to framework format for compatibility
  framework_result <- list(
    # Original framework format
    site_name = soil_test$site_name,
    soil_data = soil_test,
    crop_name = crop_name,
    target_yield_kg_ha = target_yield,
    
    # Enhanced recommendations
    N_fertilizer_kg_ha = enhanced_result$fertilizer_rates$N,
    P_fertilizer_kg_ha = enhanced_result$fertilizer_rates$P,
    K_fertilizer_kg_ha = enhanced_result$fertilizer_rates$K,
    
    # Uncertainty information
    N_confidence_80 = enhanced_result$confidence_intervals$N[c("lower_80", "upper_80")],
    P_confidence_80 = enhanced_result$confidence_intervals$P[c("lower_80", "upper_80")],
    K_confidence_80 = enhanced_result$confidence_intervals$K[c("lower_80", "upper_80")],
    
    # Yield predictions
    predicted_yield = enhanced_result$yield_prediction$expected,
    yield_confidence_80 = enhanced_result$yield_prediction$confidence_80,
    success_probability = enhanced_result$probability_of_success,
    
    # Economic analysis
    economic_analysis = enhanced_result$economic_risk,
    
    # Risk assessment
    risk_assessment = enhanced_result$risk_assessment,
    uncertainty_level = uncertainty_level,
    
    # Enhanced results (full detail)
    enhanced_results = enhanced_result,
    
    # Metadata
    calculation_method = "Enhanced Monte Carlo QUEFTS Engine",
    n_simulations = n_simulations,
    calculation_date = Sys.time()
  )
  
  class(framework_result) <- c("quefts_enhanced_recommendation", "quefts_recommendation")
  
  cat("✓ Enhanced calculation completed successfully\n")
  cat("  Method: Monte Carlo QUEFTS with", n_simulations, "simulations\n")
  cat("  Uncertainty level:", uncertainty_level, "\n")
  cat("  Success probability:", round(enhanced_result$probability_of_success * 100, 1), "%\n\n")
  
  return(framework_result)
}

#' Generate enhanced report for Monte Carlo QUEFTS results
#' 
#' @param recommendation Enhanced recommendation object
generate_enhanced_monte_carlo_report <- function(recommendation) {
  
  if (!inherits(recommendation, "quefts_enhanced_recommendation")) {
    cat("This function requires enhanced recommendation results.\n")
    return(invisible())
  }
  
  cat("\n")
  cat("=" %R% paste(rep("=", 80), collapse = "") %R% "\n")
  cat("         ENHANCED MONTE CARLO QUEFTS FERTILIZER RECOMMENDATION REPORT\n")
  cat("=" %R% paste(rep("=", 80), collapse = "") %R% "\n")
  
  # Header information
  cat("Site: ", recommendation$site_name, "\n")
  cat("Crop: ", recommendation$crop_name, "\n")
  cat("Target Yield: ", recommendation$target_yield_kg_ha, " kg/ha\n")
  cat("Calculation Method: ", recommendation$calculation_method, "\n")
  cat("Monte Carlo Simulations: ", recommendation$n_simulations, "\n")
  cat("Uncertainty Level: ", recommendation$uncertainty_level, "\n")
  cat("Analysis Date: ", format(recommendation$calculation_date), "\n")
  cat("─" %R% paste(rep("─", 80), collapse = "") %R% "\n\n")
  
  # Soil information
  soil <- recommendation$soil_data
  cat("SOIL PROPERTIES:\n")
  cat(sprintf("  pH: %.1f\n", soil$pH))
  cat(sprintf("  Soil Organic Carbon: %.1f%%\n", soil$SOC))
  cat(sprintf("  Olsen Phosphorus: %.1f mg/kg\n", soil$Olsen_P))
  cat(sprintf("  Exchangeable Potassium: %.1f cmol/kg\n", soil$Exch_K))
  cat("\n")
  
  # Enhanced fertilizer recommendations with confidence intervals
  cat("ENHANCED FERTILIZER RECOMMENDATIONS:\n")
  cat("─" %R% paste(rep("─", 80), collapse = "") %R% "\n")
  cat("Recommended Rates (with 80% confidence intervals):\n")
  cat(sprintf("  Nitrogen (N):   %6.1f kg/ha  [%6.1f - %6.1f]\n",
              recommendation$N_fertilizer_kg_ha,
              recommendation$N_confidence_80$lower_80,
              recommendation$N_confidence_80$upper_80))
  cat(sprintf("  Phosphorus (P): %6.1f kg/ha  [%6.1f - %6.1f]\n",
              recommendation$P_fertilizer_kg_ha,
              recommendation$P_confidence_80$lower_80,
              recommendation$P_confidence_80$upper_80))
  cat(sprintf("  Potassium (K):  %6.1f kg/ha  [%6.1f - %6.1f]\n",
              recommendation$K_fertilizer_kg_ha,
              recommendation$K_confidence_80$lower_80,
              recommendation$K_confidence_80$upper_80))
  cat("\n")
  
  # Yield predictions with uncertainty
  cat("YIELD PREDICTIONS:\n")
  cat("─" %R% paste(rep("─", 80), collapse = "") %R% "\n")
  cat(sprintf("Expected Yield: %6.0f kg/ha  [%6.0f - %6.0f]\n",
              recommendation$predicted_yield,
              recommendation$yield_confidence_80[1],
              recommendation$yield_confidence_80[2]))
  cat(sprintf("Probability of Achieving Target: %.1f%%\n",
              recommendation$success_probability * 100))
  cat(sprintf("Yield Uncertainty: %.1f%% (coefficient of variation)\n",
              recommendation$risk_assessment$yield_risk * 100))
  cat("\n")
  
  # Risk assessment
  cat("RISK ASSESSMENT:\n")
  cat("─" %R% paste(rep("─", 80), collapse = "") %R% "\n")
  risk <- recommendation$risk_assessment
  cat(sprintf("Overall Uncertainty: %.1f%%\n", risk$overall_uncertainty * 100))
  cat(sprintf("Fertilizer Rate Uncertainty: %.1f%%\n", risk$fertilizer_uncertainty * 100))
  
  risk_category <- if (risk$overall_uncertainty < 0.15) {
    "LOW RISK"
  } else if (risk$overall_uncertainty < 0.25) {
    "MODERATE RISK"
  } else {
    "HIGH RISK"
  }
  cat("Risk Category: ", risk_category, "\n")
  cat("\n")
  
  # Economic analysis (if available)
  if (!is.null(recommendation$economic_analysis)) {
    econ <- recommendation$economic_analysis
    cat("ECONOMIC ANALYSIS:\n")
    cat("─" %R% paste(rep("─", 80), collapse = "") %R% "\n")
    cat(sprintf("Expected Total Cost: $%.2f per hectare\n", econ$total_cost$mean))
    cat(sprintf("Expected Gross Revenue: $%.2f per hectare\n", econ$gross_revenue$mean))
    cat(sprintf("Expected Net Profit: $%.2f per hectare\n", econ$net_profit$mean))
    cat(sprintf("Probability of Profit: %.1f%%\n", econ$probability_of_profit * 100))
    cat(sprintf("Expected ROI: %.1f%%\n", econ$expected_return_on_investment * 100))
    cat("\n")
  }
  
  # Implementation recommendations
  cat("IMPLEMENTATION RECOMMENDATIONS:\n")
  cat("─" %R% paste(rep("─", 80), collapse = "") %R% "\n")
  
  if (recommendation$success_probability >= 0.8) {
    cat("✓ HIGH CONFIDENCE: Apply fertilizer as recommended\n")
    cat("  • Recommended rates have high probability of success\n")
    cat("  • Low uncertainty in recommendations\n")
  } else if (recommendation$success_probability >= 0.6) {
    cat("⚠ MODERATE CONFIDENCE: Apply fertilizer with caution\n")
    cat("  • Consider starting with lower rates (80% of recommended)\n")
    cat("  • Monitor crop response closely\n")
  } else {
    cat("⚠ LOW CONFIDENCE: Gather additional soil information\n")
    cat("  • High uncertainty in current recommendations\n")
    cat("  • Consider additional soil testing or calibration trials\n")
  }
  
  cat("  • Use split applications for nitrogen to reduce risk\n")
  cat("  • Monitor soil and crop conditions throughout the season\n")
  cat("  • Keep detailed records for future calibration\n")
  cat("\n")
  
  cat("=" %R% paste(rep("=", 80), collapse = "") %R% "\n")
  cat("                        END OF ENHANCED REPORT\n")
  cat("=" %R% paste(rep("=", 80), collapse = "") %R% "\n\n")
}

#' Demonstration of enhanced framework integration
demo_enhanced_integration <- function() {
  cat("=== ENHANCED FRAMEWORK INTEGRATION DEMONSTRATION ===\n\n")
  
  # Create example soil test
  demo_soil <- create_soil_test(
    pH = 6.2,
    SOC_percent = 1.8,
    Olsen_P_mg_kg = 15,
    Exch_K_cmol_kg = 0.8,
    site_name = "Demo Field - Enhanced Engine"
  )
  
  cat("Created demo soil test:\n")
  print(demo_soil)
  cat("\n")
  
  # Standard calculation
  cat("Running standard calculation...\n")
  standard_result <- calculate_fertilizer_needs(demo_soil, "Maize", 6000)
  
  # Enhanced calculation (if available)
  if (exists("calculate_fertilizer_recommendation")) {
    cat("Running enhanced Monte Carlo calculation...\n")
    enhanced_result <- calculate_fertilizer_needs_enhanced(
      demo_soil, "Maize", 6000,
      uncertainty_level = "medium",
      n_simulations = 500
    )
    
    # Compare results
    cat("\nCOMPARISON OF METHODS:\n")
    cat("─" %R% paste(rep("─", 50), collapse = "") %R% "\n")
    cat(sprintf("%-20s %-12s %-12s\n", "Parameter", "Standard", "Enhanced"))
    cat("─" %R% paste(rep("─", 50), collapse = "") %R% "\n")
    cat(sprintf("%-20s %12.1f %12.1f\n", "N Rate (kg/ha)", 
                standard_result$N_fertilizer_kg_ha, enhanced_result$N_fertilizer_kg_ha))
    cat(sprintf("%-20s %12.1f %12.1f\n", "P Rate (kg/ha)", 
                standard_result$P_fertilizer_kg_ha, enhanced_result$P_fertilizer_kg_ha))
    cat(sprintf("%-20s %12.1f %12.1f\n", "K Rate (kg/ha)", 
                standard_result$K_fertilizer_kg_ha, enhanced_result$K_fertilizer_kg_ha))
    cat(sprintf("%-20s %12.0f %12.0f\n", "Expected Yield", 
                standard_result$predicted_yield_kg_ha, enhanced_result$predicted_yield))
    cat("\nEnhanced method provides:\n")
    cat("• Confidence intervals for all recommendations\n")
    cat("• Probability of success assessment\n")
    cat("• Risk quantification\n")
    cat("• Economic uncertainty analysis\n")
    
    # Generate enhanced report
    cat("\nGenerating enhanced report...\n")
    generate_enhanced_monte_carlo_report(enhanced_result)
    
  } else {
    cat("Enhanced calculation engine not available.\n")
    cat("Generate standard report...\n")
    generate_fertilizer_report(standard_result)
  }
  
  cat("\n=== DEMONSTRATION COMPLETED ===\n")
}