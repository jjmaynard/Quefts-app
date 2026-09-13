# ================================================================================
# QUEFTS CALCULATION ENGINE MODULE
# Enhanced computational workflow with uncertainty propagation and Monte Carlo simulation
# ================================================================================

# Load required libraries
suppressPackageStartupMessages({
  if (!require(Rquefts, quietly = TRUE)) {
    cat("Warning: Rquefts package not available. Some functions may not work.\n")
  }
  library(dplyr)
  library(mvtnorm)  # For multivariate normal distributions
  library(boot)     # For bootstrap methods
})

cat("Loading QUEFTS Calculation Engine...\n")

# ================================================================================
# 1. ENHANCED SOIL SUPPLY CALCULATION WITH UNCERTAINTY
# ================================================================================

#' Calculate native soil nutrient supply with uncertainty propagation
#' 
#' @param pH Soil pH value ± uncertainty
#' @param SOC Soil organic carbon (g/kg) ± uncertainty  
#' @param Kex Exchangeable potassium (mmol/kg) ± uncertainty
#' @param Polsen Olsen phosphorus (mg/kg) ± uncertainty
#' @param uncertainty_params List containing uncertainty parameters
#' @param correlation_matrix Correlation matrix for soil parameters
#' @param n_samples Number of Monte Carlo samples
#' @return List containing soil supply estimates with uncertainty
nutSupply1_with_uncertainty <- function(pH, SOC, Kex, Polsen, 
                                       uncertainty_params = NULL,
                                       correlation_matrix = NULL,
                                       n_samples = 1000) {
  
  # Default uncertainty parameters if not provided
  if (is.null(uncertainty_params)) {
    uncertainty_params <- list(
      pH_cv = 0.05,      # 5% coefficient of variation
      SOC_cv = 0.15,     # 15% CV
      Kex_cv = 0.20,     # 20% CV  
      Polsen_cv = 0.25   # 25% CV
    )
  }
  
  # Extract mean values and calculate standard deviations
  pH_mean <- as.numeric(pH)
  SOC_mean <- as.numeric(SOC)
  Kex_mean <- as.numeric(Kex)
  Polsen_mean <- as.numeric(Polsen)
  
  pH_sd <- pH_mean * uncertainty_params$pH_cv
  SOC_sd <- SOC_mean * uncertainty_params$SOC_cv
  Kex_sd <- Kex_mean * uncertainty_params$Kex_cv
  Polsen_sd <- Polsen_mean * uncertainty_params$Polsen_cv
  
  # Default correlation matrix if not provided
  if (is.null(correlation_matrix)) {
    correlation_matrix <- matrix(c(
      1.0,  0.3,  0.2,  0.1,   # pH correlations
      0.3,  1.0,  0.5,  0.4,   # SOC correlations
      0.2,  0.5,  1.0,  0.3,   # Kex correlations
      0.1,  0.4,  0.3,  1.0    # Polsen correlations
    ), nrow = 4, ncol = 4)
  }
  
  # Create covariance matrix
  sds <- c(pH_sd, SOC_sd, Kex_sd, Polsen_sd)
  covariance_matrix <- diag(sds) %*% correlation_matrix %*% diag(sds)
  
  # Generate correlated samples
  means <- c(pH_mean, SOC_mean, Kex_mean, Polsen_mean)
  
  # Handle edge cases for sampling
  tryCatch({
    samples <- rmvnorm(n_samples, mean = means, sigma = covariance_matrix)
  }, error = function(e) {
    # Fall back to independent sampling if correlation matrix is problematic
    warning("Using independent sampling due to correlation matrix issues")
    samples <- cbind(
      rnorm(n_samples, pH_mean, pH_sd),
      rnorm(n_samples, SOC_mean, SOC_sd),
      rnorm(n_samples, Kex_mean, Kex_sd),
      rnorm(n_samples, Polsen_mean, Polsen_sd)
    )
  })
  
  # Ensure positive values for soil parameters
  samples[, 1] <- pmax(samples[, 1], 3.5)   # pH minimum
  samples[, 2] <- pmax(samples[, 2], 1.0)   # SOC minimum
  samples[, 3] <- pmax(samples[, 3], 0.1)   # Kex minimum
  samples[, 4] <- pmax(samples[, 4], 0.1)   # Polsen minimum
  
  colnames(samples) <- c("pH", "SOC", "Kex", "Polsen")
  
  # Calculate soil supply for each sample
  N_supply <- numeric(n_samples)
  P_supply <- numeric(n_samples)
  K_supply <- numeric(n_samples)
  
  for (i in 1:n_samples) {
    pH_i <- samples[i, "pH"]
    SOC_i <- samples[i, "SOC"]
    Kex_i <- samples[i, "Kex"]
    Polsen_i <- samples[i, "Polsen"]
    
    # Enhanced soil supply calculations based on QUEFTS methodology
    
    # Nitrogen supply (based on soil organic carbon and pH)
    N_supply[i] <- calculate_N_supply(SOC_i, pH_i)
    
    # Phosphorus supply (based on Olsen P and pH)
    P_supply[i] <- calculate_P_supply(Polsen_i, pH_i)
    
    # Potassium supply (based on exchangeable K)
    K_supply[i] <- calculate_K_supply(Kex_i, pH_i)
  }
  
  # Calculate statistics
  result <- list(
    # Sample data
    parameter_samples = samples,
    
    # Nitrogen supply
    N_supply = list(
      samples = N_supply,
      mean = mean(N_supply),
      median = median(N_supply),
      sd = sd(N_supply),
      cv = sd(N_supply) / mean(N_supply),
      quantiles = quantile(N_supply, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
      confidence_50 = quantile(N_supply, probs = c(0.25, 0.75)),
      confidence_80 = quantile(N_supply, probs = c(0.1, 0.9)),
      confidence_95 = quantile(N_supply, probs = c(0.025, 0.975))
    ),
    
    # Phosphorus supply
    P_supply = list(
      samples = P_supply,
      mean = mean(P_supply),
      median = median(P_supply),
      sd = sd(P_supply),
      cv = sd(P_supply) / mean(P_supply),
      quantiles = quantile(P_supply, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
      confidence_50 = quantile(P_supply, probs = c(0.25, 0.75)),
      confidence_80 = quantile(P_supply, probs = c(0.1, 0.9)),
      confidence_95 = quantile(P_supply, probs = c(0.025, 0.975))
    ),
    
    # Potassium supply
    K_supply = list(
      samples = K_supply,
      mean = mean(K_supply),
      median = median(K_supply),
      sd = sd(K_supply),
      cv = sd(K_supply) / mean(K_supply),
      quantiles = quantile(K_supply, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
      confidence_50 = quantile(K_supply, probs = c(0.25, 0.75)),
      confidence_80 = quantile(K_supply, probs = c(0.1, 0.9)),
      confidence_95 = quantile(K_supply, probs = c(0.025, 0.975))
    ),
    
    # Metadata
    n_samples = n_samples,
    input_means = means,
    input_uncertainties = sds,
    correlation_matrix = correlation_matrix
  )
  
  return(result)
}

# ================================================================================
# 2. INDIVIDUAL NUTRIENT SUPPLY CALCULATIONS
# ================================================================================

#' Calculate nitrogen supply from soil organic carbon
calculate_N_supply <- function(SOC, pH) {
  # QUEFTS-based nitrogen mineralization
  # Base mineralization rate adjusted by pH
  pH_factor <- pmin(1.0, pmax(0.3, (pH - 4.0) / 3.5))
  N_mineralization_rate <- 0.025 * pH_factor  # 2.5% base rate
  
  # Convert SOC (g/kg) to total N and calculate annual supply
  total_N <- SOC * 10  # Approximate total N from SOC (C:N ratio ~10:1)
  N_supply <- total_N * N_mineralization_rate
  
  return(pmax(0, N_supply))
}

#' Calculate phosphorus supply from Olsen P
calculate_P_supply <- function(Polsen, pH) {
  # QUEFTS-based P availability
  # pH affects P availability
  if (pH < 5.5) {
    pH_factor <- 0.6  # Acidic soils - Al/Fe fixation
  } else if (pH > 7.5) {
    pH_factor <- 0.7  # Alkaline soils - Ca fixation
  } else {
    pH_factor <- 1.0  # Optimal pH range
  }
  
  # Convert Olsen P to plant-available P
  # Empirical relationship: Available P = Olsen P * buffering factor
  buffer_factor <- 2.5 * pH_factor
  P_supply <- Polsen * buffer_factor
  
  return(pmax(0, P_supply))
}

#' Calculate potassium supply from exchangeable K
calculate_K_supply <- function(Kex, pH) {
  # QUEFTS-based K availability
  # Convert exchangeable K (mmol/kg) to plant-available K (kg/ha)
  # Assuming soil bulk density of 1.3 g/cm3 and 20cm depth
  soil_weight <- 1.3 * 10000 * 0.2  # kg/ha
  
  # K atomic weight = 39.1 g/mol
  K_total <- Kex * 39.1 / 1000 * soil_weight / 1000  # kg K/ha
  
  # Availability factor (typically 0.2-0.8 depending on soil type)
  pH_factor <- pmin(1.0, pmax(0.4, (pH - 3.5) / 4.0))
  availability_factor <- 0.6 * pH_factor
  
  K_supply <- K_total * availability_factor
  
  return(pmax(0, K_supply))
}

# ================================================================================
# 3. MONTE CARLO QUEFTS SIMULATION
# ================================================================================

#' Run Monte Carlo QUEFTS simulation with uncertainty propagation
#' 
#' @param soil_supply Soil supply results from nutSupply1_with_uncertainty
#' @param crop_parameters Crop parameters (yield potential, nutrient requirements)
#' @param target_yield Target yield (kg/ha)
#' @param fertilizer_efficiency Fertilizer use efficiency parameters
#' @param economic_params Economic parameters (prices, costs)
#' @param n_simulations Number of Monte Carlo simulations
#' @return Comprehensive results with uncertainty quantification
monte_carlo_quefts <- function(soil_supply, crop_parameters, target_yield,
                              fertilizer_efficiency = NULL,
                              economic_params = NULL,
                              n_simulations = 1000) {
  
  cat("Running Monte Carlo QUEFTS simulation with", n_simulations, "iterations...\n")
  
  # Default fertilizer efficiency parameters
  if (is.null(fertilizer_efficiency)) {
    fertilizer_efficiency <- list(
      N_efficiency = list(mean = 0.50, sd = 0.10),  # 50% ± 10%
      P_efficiency = list(mean = 0.20, sd = 0.05),  # 20% ± 5%
      K_efficiency = list(mean = 0.70, sd = 0.15)   # 70% ± 15%
    )
  }
  
  # Default economic parameters
  if (is.null(economic_params)) {
    economic_params <- list(
      N_price = list(mean = 1.2, sd = 0.15),        # USD/kg N
      P_price = list(mean = 2.5, sd = 0.30),        # USD/kg P2O5
      K_price = list(mean = 1.0, sd = 0.12),        # USD/kg K2O
      crop_price = list(mean = 0.30, sd = 0.03),    # USD/kg grain
      application_cost = list(mean = 25, sd = 5)    # USD/ha
    )
  }
  
  # Initialize result vectors
  N_fertilizer <- numeric(n_simulations)
  P_fertilizer <- numeric(n_simulations)
  K_fertilizer <- numeric(n_simulations)
  predicted_yield <- numeric(n_simulations)
  total_cost <- numeric(n_simulations)
  gross_revenue <- numeric(n_simulations)
  net_profit <- numeric(n_simulations)
  success_indicator <- logical(n_simulations)
  
  # Run simulations
  for (i in 1:n_simulations) {
    
    # Sample soil supply values
    if (length(soil_supply$N_supply$samples) >= i) {
      N_soil <- soil_supply$N_supply$samples[i]
      P_soil <- soil_supply$P_supply$samples[i]
      K_soil <- soil_supply$K_supply$samples[i]
    } else {
      # If fewer soil samples, resample
      idx <- sample(length(soil_supply$N_supply$samples), 1)
      N_soil <- soil_supply$N_supply$samples[idx]
      P_soil <- soil_supply$P_supply$samples[idx]
      K_soil <- soil_supply$K_supply$samples[idx]
    }
    
    # Sample fertilizer efficiency
    N_eff <- rnorm(1, fertilizer_efficiency$N_efficiency$mean, fertilizer_efficiency$N_efficiency$sd)
    P_eff <- rnorm(1, fertilizer_efficiency$P_efficiency$mean, fertilizer_efficiency$P_efficiency$sd)
    K_eff <- rnorm(1, fertilizer_efficiency$K_efficiency$mean, fertilizer_efficiency$K_efficiency$sd)
    
    # Constrain efficiency values
    N_eff <- pmax(0.1, pmin(0.9, N_eff))
    P_eff <- pmax(0.05, pmin(0.5, P_eff))
    K_eff <- pmax(0.3, pmin(1.0, K_eff))
    
    # Sample crop parameters with uncertainty
    crop_N_req <- rnorm(1, crop_parameters$N_requirement_per_ton, crop_parameters$N_requirement_per_ton * 0.1)
    crop_P_req <- rnorm(1, crop_parameters$P_requirement_per_ton, crop_parameters$P_requirement_per_ton * 0.1)
    crop_K_req <- rnorm(1, crop_parameters$K_requirement_per_ton, crop_parameters$K_requirement_per_ton * 0.1)
    
    # Calculate nutrient requirements for target yield
    target_N <- (target_yield / 1000) * crop_N_req
    target_P <- (target_yield / 1000) * crop_P_req
    target_K <- (target_yield / 1000) * crop_K_req
    
    # Calculate fertilizer requirements
    N_fertilizer[i] <- pmax(0, (target_N - N_soil) / N_eff)
    P_fertilizer[i] <- pmax(0, (target_P - P_soil) / P_eff)
    K_fertilizer[i] <- pmax(0, (target_K - K_soil) / K_eff)
    
    # Predict actual yield (considering interactions and limitations)
    actual_N_available <- N_soil + N_fertilizer[i] * N_eff
    actual_P_available <- P_soil + P_fertilizer[i] * P_eff
    actual_K_available <- K_soil + K_fertilizer[i] * K_eff
    
    # QUEFTS yield prediction with Liebig's law (most limiting nutrient)
    yield_from_N <- (actual_N_available / crop_N_req) * 1000
    yield_from_P <- (actual_P_available / crop_P_req) * 1000
    yield_from_K <- (actual_K_available / crop_K_req) * 1000
    
    # Apply yield ceiling and environmental stress
    max_potential <- rnorm(1, crop_parameters$yield_potential, crop_parameters$yield_potential * 0.1)
    environmental_stress <- rnorm(1, 0.90, 0.10)  # 90% ± 10% environmental efficiency
    environmental_stress <- pmax(0.5, pmin(1.0, environmental_stress))
    
    predicted_yield[i] <- pmin(max_potential, min(yield_from_N, yield_from_P, yield_from_K)) * environmental_stress
    predicted_yield[i] <- pmax(0, predicted_yield[i])
    
    # Economic calculations
    if (!is.null(economic_params)) {
      # Sample economic parameters
      N_price <- rnorm(1, economic_params$N_price$mean, economic_params$N_price$sd)
      P_price <- rnorm(1, economic_params$P_price$mean, economic_params$P_price$sd)
      K_price <- rnorm(1, economic_params$K_price$mean, economic_params$K_price$sd)
      crop_price <- rnorm(1, economic_params$crop_price$mean, economic_params$crop_price$sd)
      app_cost <- rnorm(1, economic_params$application_cost$mean, economic_params$application_cost$sd)
      
      # Calculate costs and revenue
      fert_cost <- N_fertilizer[i] * N_price + P_fertilizer[i] * P_price + K_fertilizer[i] * K_price
      total_cost[i] <- fert_cost + app_cost
      gross_revenue[i] <- predicted_yield[i] * crop_price
      net_profit[i] <- gross_revenue[i] - total_cost[i]
    }
    
    # Success indicator (achieving target yield)
    success_indicator[i] <- predicted_yield[i] >= target_yield
  }
  
  cat("✓ Monte Carlo simulation completed\n")
  
  # Calculate comprehensive statistics
  result <- list(
    # Fertilizer recommendations
    fertilizer_rates = list(
      N = list(
        samples = N_fertilizer,
        mean = mean(N_fertilizer),
        median = median(N_fertilizer),
        sd = sd(N_fertilizer),
        cv = sd(N_fertilizer) / mean(N_fertilizer),
        quantiles = quantile(N_fertilizer, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
        confidence_50 = quantile(N_fertilizer, probs = c(0.25, 0.75)),
        confidence_80 = quantile(N_fertilizer, probs = c(0.1, 0.9)),
        confidence_95 = quantile(N_fertilizer, probs = c(0.025, 0.975))
      ),
      P = list(
        samples = P_fertilizer,
        mean = mean(P_fertilizer),
        median = median(P_fertilizer),
        sd = sd(P_fertilizer),
        cv = sd(P_fertilizer) / mean(P_fertilizer),
        quantiles = quantile(P_fertilizer, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
        confidence_50 = quantile(P_fertilizer, probs = c(0.25, 0.75)),
        confidence_80 = quantile(P_fertilizer, probs = c(0.1, 0.9)),
        confidence_95 = quantile(P_fertilizer, probs = c(0.025, 0.975))
      ),
      K = list(
        samples = K_fertilizer,
        mean = mean(K_fertilizer),
        median = median(K_fertilizer),
        sd = sd(K_fertilizer),
        cv = sd(K_fertilizer) / mean(K_fertilizer),
        quantiles = quantile(K_fertilizer, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
        confidence_50 = quantile(K_fertilizer, probs = c(0.25, 0.75)),
        confidence_80 = quantile(K_fertilizer, probs = c(0.1, 0.9)),
        confidence_95 = quantile(K_fertilizer, probs = c(0.025, 0.975))
      )
    ),
    
    # Yield predictions
    yield_predictions = list(
      samples = predicted_yield,
      mean = mean(predicted_yield),
      median = median(predicted_yield),
      sd = sd(predicted_yield),
      cv = sd(predicted_yield) / mean(predicted_yield),
      quantiles = quantile(predicted_yield, probs = c(0.025, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.975)),
      confidence_50 = quantile(predicted_yield, probs = c(0.25, 0.75)),
      confidence_80 = quantile(predicted_yield, probs = c(0.1, 0.9)),
      confidence_95 = quantile(predicted_yield, probs = c(0.025, 0.975))
    ),
    
    # Success probability
    success_probability = mean(success_indicator),
    probability_of_success = mean(success_indicator),
    
    # Economic analysis (if parameters provided)
    economic_analysis = if (!is.null(economic_params)) {
      list(
        total_cost = list(
          mean = mean(total_cost),
          median = median(total_cost),
          sd = sd(total_cost),
          quantiles = quantile(total_cost, probs = c(0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95))
        ),
        gross_revenue = list(
          mean = mean(gross_revenue),
          median = median(gross_revenue),
          sd = sd(gross_revenue),
          quantiles = quantile(gross_revenue, probs = c(0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95))
        ),
        net_profit = list(
          mean = mean(net_profit),
          median = median(net_profit),
          sd = sd(net_profit),
          quantiles = quantile(net_profit, probs = c(0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95))
        ),
        probability_of_profit = mean(net_profit > 0),
        break_even_probability = mean(gross_revenue >= total_cost),
        expected_return_on_investment = mean(net_profit / total_cost, na.rm = TRUE)
      )
    } else {
      NULL
    },
    
    # Risk metrics
    risk_assessment = list(
      yield_risk = sd(predicted_yield) / mean(predicted_yield),
      fertilizer_uncertainty = sqrt(mean(c(
        (sd(N_fertilizer) / mean(N_fertilizer))^2,
        (sd(P_fertilizer) / mean(P_fertilizer))^2,
        (sd(K_fertilizer) / mean(K_fertilizer))^2
      ))),
      overall_uncertainty = sqrt(mean(c(
        (sd(predicted_yield) / mean(predicted_yield))^2,
        (sd(N_fertilizer) / mean(N_fertilizer))^2,
        (sd(P_fertilizer) / mean(P_fertilizer))^2,
        (sd(K_fertilizer) / mean(K_fertilizer))^2
      )))
    ),
    
    # Simulation metadata
    simulation_info = list(
      n_simulations = n_simulations,
      target_yield = target_yield,
      crop_parameters = crop_parameters,
      fertilizer_efficiency = fertilizer_efficiency,
      economic_params = economic_params
    )
  )
  
  return(result)
}

# ================================================================================
# 4. MAIN CALCULATION FUNCTION
# ================================================================================

#' Main function to calculate fertilizer recommendations with uncertainty
#' 
#' @param soil_data Soil data with uncertainty parameters
#' @param crop Crop name or parameters
#' @param target_yield Target yield (kg/ha)
#' @param uncertainty_level Level of uncertainty ("low", "medium", "high")
#' @param economic_params Economic parameters for cost-benefit analysis
#' @param n_simulations Number of Monte Carlo simulations
#' @return Comprehensive fertilizer recommendations with uncertainty quantification
calculate_fertilizer_recommendation <- function(soil_data, crop, target_yield, 
                                              uncertainty_level = "medium",
                                              economic_params = NULL,
                                              n_simulations = 1000) {
  
  cat("=== QUEFTS FERTILIZER RECOMMENDATION CALCULATION ===\n")
  cat("Crop:", crop, "\n")
  cat("Target Yield:", target_yield, "kg/ha\n")
  cat("Uncertainty Level:", uncertainty_level, "\n")
  cat("Simulations:", n_simulations, "\n\n")
  
  # Validate inputs
  required_soil_params <- c("pH", "SOC", "Kex", "Polsen")
  missing_params <- setdiff(required_soil_params, names(soil_data))
  if (length(missing_params) > 0) {
    stop("Missing required soil parameters: ", paste(missing_params, collapse = ", "))
  }
  
  # Set uncertainty parameters based on uncertainty level
  uncertainty_params <- switch(uncertainty_level,
    "low" = list(
      pH_cv = 0.03,
      SOC_cv = 0.10,
      Kex_cv = 0.15,
      Polsen_cv = 0.20
    ),
    "medium" = list(
      pH_cv = 0.05,
      SOC_cv = 0.15,
      Kex_cv = 0.20,
      Polsen_cv = 0.25
    ),
    "high" = list(
      pH_cv = 0.08,
      SOC_cv = 0.25,
      Kex_cv = 0.30,
      Polsen_cv = 0.35
    ),
    # Default to medium
    list(
      pH_cv = 0.05,
      SOC_cv = 0.15,
      Kex_cv = 0.20,
      Polsen_cv = 0.25
    )
  )
  
  # Get crop parameters
  if (is.character(crop)) {
    crop_parameters <- get_crop_parameters(crop)
  } else {
    crop_parameters <- crop
  }
  
  cat("STEP 1: Calculating soil nutrient supply with uncertainty...\n")
  
  # Step 1: Calculate native soil supply with uncertainty
  soil_supply <- nutSupply1_with_uncertainty(
    pH = soil_data$pH,
    SOC = soil_data$SOC,
    Kex = soil_data$Kex,
    Polsen = soil_data$Polsen,
    uncertainty_params = uncertainty_params,
    correlation_matrix = soil_data$correlation_matrix,
    n_samples = n_simulations
  )
  
  cat("✓ Soil supply calculated\n")
  cat("  N supply: ", round(soil_supply$N_supply$mean, 1), " ± ", round(soil_supply$N_supply$sd, 1), " kg/ha\n")
  cat("  P supply: ", round(soil_supply$P_supply$mean, 1), " ± ", round(soil_supply$P_supply$sd, 1), " kg/ha\n")
  cat("  K supply: ", round(soil_supply$K_supply$mean, 1), " ± ", round(soil_supply$K_supply$sd, 1), " kg/ha\n\n")
  
  cat("STEP 2: Running Monte Carlo QUEFTS simulation...\n")
  
  # Step 2: Monte Carlo simulation for uncertainty propagation
  recommendations <- monte_carlo_quefts(
    soil_supply = soil_supply,
    crop_parameters = crop_parameters,
    target_yield = target_yield,
    fertilizer_efficiency = NULL,  # Use defaults
    economic_params = economic_params,
    n_simulations = n_simulations
  )
  
  cat("✓ Monte Carlo simulation completed\n\n")
  
  cat("STEP 3: Generating probabilistic recommendations...\n")
  
  # Step 3: Generate probabilistic recommendations with confidence intervals
  result <- list(
    # Main recommendation outputs
    fertilizer_rates = list(
      N = recommendations$fertilizer_rates$N$median,
      P = recommendations$fertilizer_rates$P$median,
      K = recommendations$fertilizer_rates$K$median
    ),
    
    # Confidence intervals
    confidence_intervals = list(
      N = list(
        lower_80 = recommendations$fertilizer_rates$N$confidence_80[1],
        upper_80 = recommendations$fertilizer_rates$N$confidence_80[2],
        lower_90 = recommendations$fertilizer_rates$N$confidence_90[1],
        upper_90 = recommendations$fertilizer_rates$N$confidence_90[2]
      ),
      P = list(
        lower_80 = recommendations$fertilizer_rates$P$confidence_80[1],
        upper_80 = recommendations$fertilizer_rates$P$confidence_80[2],
        lower_90 = recommendations$fertilizer_rates$P$confidence_90[1],
        upper_90 = recommendations$fertilizer_rates$P$confidence_90[2]
      ),
      K = list(
        lower_80 = recommendations$fertilizer_rates$K$confidence_80[1],
        upper_80 = recommendations$fertilizer_rates$K$confidence_80[2],
        lower_90 = recommendations$fertilizer_rates$K$confidence_90[1],
        upper_90 = recommendations$fertilizer_rates$K$confidence_90[2]
      )
    ),
    
    # Probability of success
    probability_of_success = recommendations$success_probability,
    
    # Economic risk assessment
    economic_risk = recommendations$economic_analysis,
    
    # Additional outputs
    yield_prediction = list(
      expected = recommendations$yield_predictions$median,
      confidence_80 = recommendations$yield_predictions$confidence_80,
      confidence_90 = recommendations$yield_predictions$confidence_90,
      uncertainty = recommendations$yield_predictions$cv
    ),
    
    risk_assessment = recommendations$risk_assessment,
    
    # Raw simulation results for further analysis
    detailed_results = recommendations,
    soil_supply_analysis = soil_supply,
    
    # Metadata
    input_parameters = list(
      soil_data = soil_data,
      crop = crop,
      target_yield = target_yield,
      uncertainty_level = uncertainty_level,
      n_simulations = n_simulations,
      calculation_date = Sys.time()
    )
  )
  
  cat("✓ Probabilistic recommendations generated\n\n")
  
  # Generate summary report
  generate_calculation_summary(result)
  
  return(result)
}

# ================================================================================
# 5. CROP PARAMETER DATABASE
# ================================================================================

#' Get crop parameters for QUEFTS calculations
#' 
#' @param crop_name Name of the crop
#' @return List of crop parameters
#' The crop parameter database backing get_crop_parameters() and
#' list_crop_parameters(). Kept as one internal helper so the two never drift.
.crop_parameter_database <- function() {
  list(
    "Maize" = list(
      yield_potential = 8000,          # kg/ha
      N_requirement_per_ton = 25,      # kg N per ton grain
      P_requirement_per_ton = 8,       # kg P per ton grain
      K_requirement_per_ton = 20,      # kg K per ton grain
      harvest_index = 0.45,
      growing_season = 120             # days
    ),

    "Rice" = list(
      yield_potential = 7000,
      N_requirement_per_ton = 20,
      P_requirement_per_ton = 6,
      K_requirement_per_ton = 25,
      harvest_index = 0.50,
      growing_season = 140
    ),

    "Wheat" = list(
      yield_potential = 6000,
      N_requirement_per_ton = 30,
      P_requirement_per_ton = 10,
      K_requirement_per_ton = 15,
      harvest_index = 0.40,
      growing_season = 150
    ),

    "Soybean" = list(
      yield_potential = 4000,
      N_requirement_per_ton = 80,      # High N requirement but fixes N
      P_requirement_per_ton = 12,
      K_requirement_per_ton = 35,
      harvest_index = 0.35,
      growing_season = 110
    ),

    "Cassava" = list(
      yield_potential = 25000,         # Fresh tuber yield
      N_requirement_per_ton = 5,
      P_requirement_per_ton = 2,
      K_requirement_per_ton = 8,
      harvest_index = 0.60,
      growing_season = 300
    )
  )
}

get_crop_parameters <- function(crop_name) {
  crop_db <- .crop_parameter_database()

  if (crop_name %in% names(crop_db)) {
    return(crop_db[[crop_name]])
  } else {
    warning("Crop '", crop_name, "' not found in database. Using Maize defaults.")
    return(crop_db[["Maize"]])
  }
}

#' List every crop in the parameter database, with its parameters
#'
#' Added for the Plumber API's GET /crops endpoint (see plumber.R) -- lets a
#' caller discover valid `crop` values instead of having them hardcoded
#' independently in the API layer.
list_crop_parameters <- function() {
  .crop_parameter_database()
}

# ================================================================================
# 6. REPORTING FUNCTIONS
# ================================================================================

#' Generate calculation summary report
#' 
#' @param results Results from calculate_fertilizer_recommendation
generate_calculation_summary <- function(results) {
  
  cat("CALCULATION SUMMARY REPORT\n")
  cat("=" %R% paste(rep("=", 60), collapse = "") %R% "\n")
  
  # Input summary
  cat("INPUT PARAMETERS:\n")
  cat("Crop: ", results$input_parameters$crop, "\n")
  cat("Target Yield: ", results$input_parameters$target_yield, " kg/ha\n")
  cat("Uncertainty Level: ", results$input_parameters$uncertainty_level, "\n")
  cat("Simulations: ", results$input_parameters$n_simulations, "\n\n")
  
  # Soil information
  soil <- results$input_parameters$soil_data
  cat("SOIL PROPERTIES:\n")
  cat(sprintf("pH: %.1f\n", soil$pH))
  cat(sprintf("SOC: %.1f g/kg\n", soil$SOC))
  cat(sprintf("Exchangeable K: %.1f mmol/kg\n", soil$Kex))
  cat(sprintf("Olsen P: %.1f mg/kg\n", soil$Polsen))
  cat("\n")
  
  # Fertilizer recommendations
  cat("FERTILIZER RECOMMENDATIONS (with 80% confidence intervals):\n")
  cat("─" %R% paste(rep("─", 60), collapse = "") %R% "\n")
  
  fert <- results$fertilizer_rates
  conf <- results$confidence_intervals
  
  cat(sprintf("Nitrogen (N):   %6.1f kg/ha  [%6.1f - %6.1f]\n",
              fert$N, conf$N$lower_80, conf$N$upper_80))
  cat(sprintf("Phosphorus (P): %6.1f kg/ha  [%6.1f - %6.1f]\n",
              fert$P, conf$P$lower_80, conf$P$upper_80))
  cat(sprintf("Potassium (K):  %6.1f kg/ha  [%6.1f - %6.1f]\n",
              fert$K, conf$K$lower_80, conf$K$upper_80))
  cat("\n")
  
  # Yield predictions
  yield <- results$yield_prediction
  cat("YIELD PREDICTIONS:\n")
  cat("─" %R% paste(rep("─", 60), collapse = "") %R% "\n")
  cat(sprintf("Expected Yield: %6.0f kg/ha  [%6.0f - %6.0f]\n",
              yield$expected, yield$confidence_80[1], yield$confidence_80[2]))
  cat(sprintf("Probability of Success: %.1f%%\n", results$probability_of_success * 100))
  cat(sprintf("Yield Uncertainty: %.1f%% (CV)\n", yield$uncertainty * 100))
  cat("\n")
  
  # Economic analysis (if available)
  if (!is.null(results$economic_risk)) {
    econ <- results$economic_risk
    cat("ECONOMIC ANALYSIS:\n")
    cat("─" %R% paste(rep("─", 60), collapse = "") %R% "\n")
    cat(sprintf("Expected Cost: $%.2f per hectare\n", econ$total_cost$mean))
    cat(sprintf("Expected Revenue: $%.2f per hectare\n", econ$gross_revenue$mean))
    cat(sprintf("Expected Profit: $%.2f per hectare\n", econ$net_profit$mean))
    cat(sprintf("Probability of Profit: %.1f%%\n", econ$probability_of_profit * 100))
    cat("\n")
  }
  
  # Risk assessment
  risk <- results$risk_assessment
  cat("RISK ASSESSMENT:\n")
  cat("─" %R% paste(rep("─", 60), collapse = "") %R% "\n")
  cat(sprintf("Overall Uncertainty: %.1f%%\n", risk$overall_uncertainty * 100))
  cat(sprintf("Fertilizer Uncertainty: %.1f%%\n", risk$fertilizer_uncertainty * 100))
  cat(sprintf("Yield Risk: %.1f%%\n", risk$yield_risk * 100))
  
  risk_category <- if (risk$overall_uncertainty < 0.15) {
    "LOW"
  } else if (risk$overall_uncertainty < 0.25) {
    "MEDIUM"
  } else {
    "HIGH"
  }
  cat("Risk Category: ", risk_category, "\n")
  
  cat("\n" %R% paste(rep("=", 70), collapse = "") %R% "\n")
  cat("Calculation completed at: ", format(results$input_parameters$calculation_date), "\n")
}

# Fix string concatenation operator if not defined
if (!exists("%R%")) {
  `%R%` <- function(x, y) paste0(x, y)
}

# ================================================================================
# MODULE INITIALIZATION
# ================================================================================

cat("✓ QUEFTS Calculation Engine loaded successfully\n")
cat("Main function: calculate_fertilizer_recommendation(soil_data, crop, target_yield, ...)\n")
cat("Available crops:", paste(names(list(
  "Maize" = 1, "Rice" = 1, "Wheat" = 1, "Soybean" = 1, "Cassava" = 1
)), collapse = ", "), "\n\n")

# Example usage message
cat("Example usage:\n")
cat("soil_data <- list(pH = 6.2, SOC = 18, Kex = 8, Polsen = 15)\n")
cat("result <- calculate_fertilizer_recommendation(soil_data, 'Maize', 6000)\n")
cat("print(result$fertilizer_rates)\n\n")
