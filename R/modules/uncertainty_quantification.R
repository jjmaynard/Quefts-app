# ================================================================================
# UNCERTAINTY QUANTIFICATION MODULE
# Probabilistic analysis of recommendations based on data quality
# ================================================================================

# Required packages for uncertainty analysis
uncertainty_packages <- c("mvtnorm", "MCMCpack", "boot", "truncnorm", "ggplot2", "dplyr")

for (pkg in uncertainty_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste("Installing", pkg, "package..."))
    install.packages(pkg)
  }
}

# Load required packages
suppressMessages({
  library(mvtnorm)
  library(boot)
  library(ggplot2)
  library(dplyr)
})

# ================================================================================
# 1. UNCERTAINTY PARAMETER DEFINITIONS
# ================================================================================

#' Define uncertainty parameters for different data quality levels
#' 
#' @param data_quality Quality level: "global_maps", "regional_refined", "field_observed", "laboratory_analyzed"
#' @return List of uncertainty parameters
define_uncertainty_parameters <- function(data_quality) {
  
  uncertainty_params <- list(
    
    # Global soil maps (Tier 1) - High uncertainty
    "global_maps" = list(
      pH = list(bias = 0, sd = 0.5, min = 3.5, max = 9.0),
      SOC = list(bias = 0, cv = 0.35, min = 0.5, max = 100),  # 35% coefficient of variation
      Olsen_P = list(bias = -2, cv = 0.6, min = 0.1, max = 100),  # Often underestimated
      Exch_K = list(bias = 0, cv = 0.5, min = 0.1, max = 50),
      Total_N = list(bias = 0, cv = 0.4, min = 0.1, max = 10)
    ),
    
    # Regional calibration (Tier 2) - Medium uncertainty
    "regional_refined" = list(
      pH = list(bias = 0, sd = 0.3, min = 3.5, max = 9.0),
      SOC = list(bias = 0, cv = 0.25, min = 0.5, max = 100),
      Olsen_P = list(bias = -1, cv = 0.4, min = 0.1, max = 100),
      Exch_K = list(bias = 0, cv = 0.35, min = 0.1, max = 50),
      Total_N = list(bias = 0, cv = 0.3, min = 0.1, max = 10)
    ),
    
    # Field observations (Tier 3) - Low uncertainty
    "field_observed" = list(
      pH = list(bias = 0, sd = 0.2, min = 3.5, max = 9.0),
      SOC = list(bias = 0, cv = 0.15, min = 0.5, max = 100),
      Olsen_P = list(bias = 0, cv = 0.25, min = 0.1, max = 100),
      Exch_K = list(bias = 0, cv = 0.2, min = 0.1, max = 50),
      Total_N = list(bias = 0, cv = 0.2, min = 0.1, max = 10)
    ),
    
    # Laboratory analysis (Tier 4) - Very low uncertainty
    "laboratory_analyzed" = list(
      pH = list(bias = 0, sd = 0.05, min = 3.5, max = 9.0),
      SOC = list(bias = 0, cv = 0.05, min = 0.5, max = 100),
      Olsen_P = list(bias = 0, cv = 0.08, min = 0.1, max = 100),
      Exch_K = list(bias = 0, cv = 0.05, min = 0.1, max = 50),
      Total_N = list(bias = 0, cv = 0.05, min = 0.1, max = 10)
    )
  )
  
  return(uncertainty_params[[data_quality]])
}

#' Define correlation structure between soil parameters
define_parameter_correlations <- function() {
  
  # Correlation matrix for soil parameters
  # Based on typical relationships in tropical soils
  param_names <- c("pH", "SOC", "Olsen_P", "Exch_K", "Total_N")
  
  correlation_matrix <- matrix(c(
    1.0,  0.3,  0.4,  0.2,  0.2,   # pH
    0.3,  1.0,  0.5,  0.3,  0.8,   # SOC
    0.4,  0.5,  1.0,  0.3,  0.4,   # Olsen_P
    0.2,  0.3,  0.3,  1.0,  0.2,   # Exch_K
    0.2,  0.8,  0.4,  0.2,  1.0    # Total_N
  ), nrow = 5, ncol = 5, byrow = TRUE)
  
  rownames(correlation_matrix) <- param_names
  colnames(correlation_matrix) <- param_names
  
  return(correlation_matrix)
}

# ================================================================================
# 2. MONTE CARLO SIMULATION ENGINE
# ================================================================================

#' Generate parameter samples accounting for uncertainty and correlations
#' 
#' @param soil_data Soil data with uncertainty information
#' @param n_samples Number of Monte Carlo samples
#' @param use_correlations Whether to account for parameter correlations
generate_parameter_samples <- function(soil_data, n_samples = 1000, use_correlations = TRUE) {
  
  # Get uncertainty parameters for data quality level
  uncertainty_params <- define_uncertainty_parameters(soil_data$data_quality)
  
  if (is.null(uncertainty_params)) {
    stop("Unknown data quality level:", soil_data$data_quality)
  }
  
  # Extract soil properties
  soil_props <- soil_data$soil_properties
  param_names <- names(uncertainty_params)
  
  # Initialize sample matrix
  samples <- matrix(NA, nrow = n_samples, ncol = length(param_names))
  colnames(samples) <- param_names
  
  if (use_correlations) {
    # Generate correlated samples
    samples <- generate_correlated_samples(soil_props, uncertainty_params, n_samples)
  } else {
    # Generate independent samples
    samples <- generate_independent_samples(soil_props, uncertainty_params, n_samples)
  }
  
  # Apply bounds to ensure realistic values
  samples <- apply_parameter_bounds(samples, uncertainty_params)
  
  return(samples)
}

#' Generate correlated parameter samples
generate_correlated_samples <- function(soil_props, uncertainty_params, n_samples) {
  
  param_names <- names(uncertainty_params)
  n_params <- length(param_names)
  
  # Get correlation matrix
  correlation_matrix <- define_parameter_correlations()
  correlation_matrix <- correlation_matrix[param_names, param_names]
  
  # Standardize parameters and generate correlated normal samples
  standardized_samples <- rmvnorm(n_samples, mean = rep(0, n_params), sigma = correlation_matrix)
  colnames(standardized_samples) <- param_names
  
  # Transform to original scale
  samples <- matrix(NA, nrow = n_samples, ncol = n_params)
  colnames(samples) <- param_names
  
  for (param in param_names) {
    if (param %in% names(soil_props)) {
      param_value <- soil_props[[param]]
      param_uncertainty <- uncertainty_params[[param]]
      
      # Transform standardized samples to parameter scale
      if (!is.null(param_uncertainty$sd)) {
        # Normal distribution
        samples[, param] <- param_value + param_uncertainty$bias + 
                           standardized_samples[, param] * param_uncertainty$sd
      } else if (!is.null(param_uncertainty$cv)) {
        # Log-normal distribution for positive parameters
        sigma <- sqrt(log(1 + param_uncertainty$cv^2))
        mu <- log(param_value + param_uncertainty$bias) - 0.5 * sigma^2
        samples[, param] <- exp(mu + standardized_samples[, param] * sigma)
      }
    }
  }
  
  return(samples)
}

#' Generate independent parameter samples
generate_independent_samples <- function(soil_props, uncertainty_params, n_samples) {
  
  param_names <- names(uncertainty_params)
  samples <- matrix(NA, nrow = n_samples, ncol = length(param_names))
  colnames(samples) <- param_names
  
  for (param in param_names) {
    if (param %in% names(soil_props)) {
      param_value <- soil_props[[param]]
      param_uncertainty <- uncertainty_params[[param]]
      
      if (!is.null(param_uncertainty$sd)) {
        # Normal distribution
        samples[, param] <- rnorm(n_samples, 
                                 mean = param_value + param_uncertainty$bias,
                                 sd = param_uncertainty$sd)
      } else if (!is.null(param_uncertainty$cv)) {
        # Log-normal distribution
        mean_adj <- param_value + param_uncertainty$bias
        sigma <- sqrt(log(1 + param_uncertainty$cv^2))
        mu <- log(mean_adj) - 0.5 * sigma^2
        samples[, param] <- rlnorm(n_samples, meanlog = mu, sdlog = sigma)
      }
    }
  }
  
  return(samples)
}

#' Apply parameter bounds to ensure realistic values
apply_parameter_bounds <- function(samples, uncertainty_params) {
  
  for (param in colnames(samples)) {
    param_uncertainty <- uncertainty_params[[param]]
    
    if (!is.null(param_uncertainty$min)) {
      samples[, param] <- pmax(samples[, param], param_uncertainty$min)
    }
    
    if (!is.null(param_uncertainty$max)) {
      samples[, param] <- pmin(samples[, param], param_uncertainty$max)
    }
  }
  
  return(samples)
}

# ================================================================================
# 3. QUEFTS UNCERTAINTY PROPAGATION
# ================================================================================

#' Run QUEFTS with uncertainty propagation
#' 
#' @param soil_data Soil data with uncertainty
#' @param crop_name Target crop
#' @param target_yield Target yield (kg/ha)
#' @param fertilizer_prices Economic parameters
#' @param n_simulations Number of Monte Carlo simulations
run_quefts_with_uncertainty <- function(soil_data, crop_name, target_yield, 
                                       fertilizer_prices = NULL, n_simulations = 1000) {
  
  cat("Running QUEFTS with uncertainty propagation...\n")
  cat("Simulations:", n_simulations, "\n")
  cat("Data quality:", soil_data$data_quality, "\n")
  
  # Generate parameter samples
  param_samples <- generate_parameter_samples(soil_data, n_simulations)
  
  # Initialize results storage
  results <- list(
    fertilizer_rates = matrix(NA, nrow = n_simulations, ncol = 3),
    predicted_yields = numeric(n_simulations),
    native_yields = numeric(n_simulations),
    economic_returns = numeric(n_simulations),
    success_indicators = logical(n_simulations)
  )
  
  colnames(results$fertilizer_rates) <- c("N", "P", "K")
  
  # Progress tracking
  progress_points <- seq(1, n_simulations, length.out = 10)
  
  # Run simulations
  for (i in 1:n_simulations) {
    
    if (i %in% progress_points) {
      cat("Progress:", round(100 * i / n_simulations), "%\n")
    }
    
    # Create soil data for this simulation
    sim_soil_data <- create_simulation_soil_data(param_samples[i, ], soil_data)
    
    tryCatch({
      # Run QUEFTS calculation for this sample
      quefts_result <- calculate_fertilizer_needs(
        soil_data = sim_soil_data,
        crop_name = crop_name,
        target_yield_kg_ha = target_yield
      )
      
      # Store results
      if (!is.null(quefts_result)) {
        results$fertilizer_rates[i, "N"] <- quefts_result$fertilizer_recommendation$N_kg_ha
        results$fertilizer_rates[i, "P"] <- quefts_result$fertilizer_recommendation$P_kg_ha
        results$fertilizer_rates[i, "K"] <- quefts_result$fertilizer_recommendation$K_kg_ha
        results$predicted_yields[i] <- quefts_result$fertilizer_recommendation$predicted_yield
        results$native_yields[i] <- quefts_result$native_supply$yield
        
        # Calculate economic return if prices provided
        if (!is.null(fertilizer_prices)) {
          fert_cost <- (quefts_result$fertilizer_recommendation$N_kg_ha * fertilizer_prices$N_per_kg +
                       quefts_result$fertilizer_recommendation$P_kg_ha * fertilizer_prices$P_per_kg +
                       quefts_result$fertilizer_recommendation$K_kg_ha * fertilizer_prices$K_per_kg)
          
          additional_yield <- quefts_result$fertilizer_recommendation$predicted_yield - quefts_result$native_supply$yield
          additional_revenue <- additional_yield * fertilizer_prices$crop_price_per_kg
          
          results$economic_returns[i] <- additional_revenue - fert_cost
        }
        
        # Success indicator (achieving target yield within 10%)
        results$success_indicators[i] <- (quefts_result$fertilizer_recommendation$predicted_yield >= target_yield * 0.9)
      }
      
    }, error = function(e) {
      # Handle simulation errors
      warning(paste("Simulation", i, "failed:", e$message))
    })
  }
  
  # Calculate summary statistics
  uncertainty_results <- calculate_uncertainty_statistics(results, target_yield, fertilizer_prices)
  
  # Add metadata
  uncertainty_results$metadata <- list(
    n_simulations = n_simulations,
    data_quality = soil_data$data_quality,
    uncertainty_tier = soil_data$uncertainty_tier,
    crop = crop_name,
    target_yield = target_yield,
    simulation_date = Sys.time()
  )
  
  cat("Uncertainty analysis complete.\n")
  
  return(uncertainty_results)
}

#' Create soil data for individual simulation
create_simulation_soil_data <- function(param_sample, original_soil_data) {
  
  sim_soil <- list(
    site_name = paste(original_soil_data$site_name, "sim", sep = "_"),
    pH = param_sample["pH"],
    OC = param_sample["SOC"],
    Olsen_P = param_sample["Olsen_P"],
    Exch_K = param_sample["Exch_K"],
    Total_N = param_sample["Total_N"]
  )
  
  # Remove NA values
  sim_soil <- sim_soil[!is.na(sim_soil)]
  
  return(sim_soil)
}

# ================================================================================
# 4. UNCERTAINTY STATISTICS AND ANALYSIS
# ================================================================================

#' Calculate comprehensive uncertainty statistics
calculate_uncertainty_statistics <- function(results, target_yield, fertilizer_prices) {
  
  # Remove failed simulations (NA values)
  valid_indices <- complete.cases(results$fertilizer_rates)
  
  if (sum(valid_indices) == 0) {
    stop("No valid simulation results")
  }
  
  # Filter to valid results only
  fert_rates <- results$fertilizer_rates[valid_indices, ]
  pred_yields <- results$predicted_yields[valid_indices]
  native_yields <- results$native_yields[valid_indices]
  econ_returns <- results$economic_returns[valid_indices]
  success_rates <- results$success_indicators[valid_indices]
  
  n_valid <- sum(valid_indices)
  
  cat("Valid simulations:", n_valid, "\n")
  
  # Fertilizer rate statistics
  fertilizer_stats <- list(
    N = list(
      mean = mean(fert_rates[, "N"], na.rm = TRUE),
      median = median(fert_rates[, "N"], na.rm = TRUE),
      sd = sd(fert_rates[, "N"], na.rm = TRUE),
      q025 = quantile(fert_rates[, "N"], 0.025, na.rm = TRUE),
      q05 = quantile(fert_rates[, "N"], 0.05, na.rm = TRUE),
      q25 = quantile(fert_rates[, "N"], 0.25, na.rm = TRUE),
      q75 = quantile(fert_rates[, "N"], 0.75, na.rm = TRUE),
      q95 = quantile(fert_rates[, "N"], 0.95, na.rm = TRUE),
      q975 = quantile(fert_rates[, "N"], 0.975, na.rm = TRUE)
    ),
    P = list(
      mean = mean(fert_rates[, "P"], na.rm = TRUE),
      median = median(fert_rates[, "P"], na.rm = TRUE),
      sd = sd(fert_rates[, "P"], na.rm = TRUE),
      q025 = quantile(fert_rates[, "P"], 0.025, na.rm = TRUE),
      q05 = quantile(fert_rates[, "P"], 0.05, na.rm = TRUE),
      q25 = quantile(fert_rates[, "P"], 0.25, na.rm = TRUE),
      q75 = quantile(fert_rates[, "P"], 0.75, na.rm = TRUE),
      q95 = quantile(fert_rates[, "P"], 0.95, na.rm = TRUE),
      q975 = quantile(fert_rates[, "P"], 0.975, na.rm = TRUE)
    ),
    K = list(
      mean = mean(fert_rates[, "K"], na.rm = TRUE),
      median = median(fert_rates[, "K"], na.rm = TRUE),
      sd = sd(fert_rates[, "K"], na.rm = TRUE),
      q025 = quantile(fert_rates[, "K"], 0.025, na.rm = TRUE),
      q05 = quantile(fert_rates[, "K"], 0.05, na.rm = TRUE),
      q25 = quantile(fert_rates[, "K"], 0.25, na.rm = TRUE),
      q75 = quantile(fert_rates[, "K"], 0.75, na.rm = TRUE),
      q95 = quantile(fert_rates[, "K"], 0.95, na.rm = TRUE),
      q975 = quantile(fert_rates[, "K"], 0.975, na.rm = TRUE)
    )
  )
  
  # Yield statistics
  yield_stats <- list(
    predicted = list(
      mean = mean(pred_yields, na.rm = TRUE),
      median = median(pred_yields, na.rm = TRUE),
      sd = sd(pred_yields, na.rm = TRUE),
      q025 = quantile(pred_yields, 0.025, na.rm = TRUE),
      q05 = quantile(pred_yields, 0.05, na.rm = TRUE),
      q25 = quantile(pred_yields, 0.25, na.rm = TRUE),
      q75 = quantile(pred_yields, 0.75, na.rm = TRUE),
      q95 = quantile(pred_yields, 0.95, na.rm = TRUE),
      q975 = quantile(pred_yields, 0.975, na.rm = TRUE)
    ),
    native = list(
      mean = mean(native_yields, na.rm = TRUE),
      median = median(native_yields, na.rm = TRUE),
      sd = sd(native_yields, na.rm = TRUE),
      q025 = quantile(native_yields, 0.025, na.rm = TRUE),
      q975 = quantile(native_yields, 0.975, na.rm = TRUE)
    )
  )
  
  # Success probability
  success_probability <- mean(success_rates, na.rm = TRUE)
  
  # Economic statistics
  economic_stats <- NULL
  if (!is.null(fertilizer_prices) && !all(is.na(econ_returns))) {
    economic_stats <- list(
      mean_return = mean(econ_returns, na.rm = TRUE),
      median_return = median(econ_returns, na.rm = TRUE),
      sd_return = sd(econ_returns, na.rm = TRUE),
      q025 = quantile(econ_returns, 0.025, na.rm = TRUE),
      q05 = quantile(econ_returns, 0.05, na.rm = TRUE),
      q25 = quantile(econ_returns, 0.25, na.rm = TRUE),
      q75 = quantile(econ_returns, 0.75, na.rm = TRUE),
      q95 = quantile(econ_returns, 0.95, na.rm = TRUE),
      q975 = quantile(econ_returns, 0.975, na.rm = TRUE),
      prob_profit = mean(econ_returns > 0, na.rm = TRUE),
      var_95 = quantile(econ_returns, 0.05, na.rm = TRUE)  # Value at Risk
    )
  }
  
  # Risk assessment
  risk_assessment <- assess_recommendation_risk(fertilizer_stats, yield_stats, economic_stats, target_yield)
  
  # Compile results
  uncertainty_analysis <- list(
    fertilizer_recommendations = fertilizer_stats,
    yield_predictions = yield_stats,
    economic_analysis = economic_stats,
    success_probability = success_probability,
    risk_assessment = risk_assessment,
    raw_results = list(
      fertilizer_rates = fert_rates,
      predicted_yields = pred_yields,
      native_yields = native_yields,
      economic_returns = econ_returns
    ),
    n_valid_simulations = n_valid
  )
  
  return(uncertainty_analysis)
}

#' Assess risk of recommendations
assess_recommendation_risk <- function(fert_stats, yield_stats, econ_stats, target_yield) {
  
  risk_assessment <- list()
  
  # Fertilizer rate uncertainty
  n_cv <- fert_stats$N$sd / fert_stats$N$mean
  p_cv <- fert_stats$P$sd / fert_stats$P$mean
  k_cv <- fert_stats$K$sd / fert_stats$K$mean
  
  risk_assessment$fertilizer_uncertainty <- list(
    N_cv = n_cv,
    P_cv = p_cv,
    K_cv = k_cv,
    overall_cv = mean(c(n_cv, p_cv, k_cv), na.rm = TRUE)
  )
  
  # Yield risk
  yield_cv <- yield_stats$predicted$sd / yield_stats$predicted$mean
  prob_target_achievement <- mean(yield_stats$predicted$q975 >= target_yield * 0.9, na.rm = TRUE)
  
  risk_assessment$yield_risk <- list(
    cv = yield_cv,
    prob_target_achievement = prob_target_achievement,
    downside_risk = max(0, target_yield - yield_stats$predicted$q05) / target_yield
  )
  
  # Economic risk
  if (!is.null(econ_stats)) {
    risk_assessment$economic_risk <- list(
      prob_loss = 1 - econ_stats$prob_profit,
      expected_loss = ifelse(econ_stats$mean_return < 0, abs(econ_stats$mean_return), 0),
      var_95 = econ_stats$var_95  # 95% Value at Risk
    )
  }
  
  # Overall risk score (0-1, where 1 is highest risk)
  risk_components <- c(
    risk_assessment$fertilizer_uncertainty$overall_cv * 0.3,
    risk_assessment$yield_risk$cv * 0.4,
    ifelse(!is.null(risk_assessment$economic_risk), risk_assessment$economic_risk$prob_loss * 0.3, 0)
  )
  
  risk_assessment$overall_risk_score <- sum(risk_components, na.rm = TRUE)
  
  # Risk category
  if (risk_assessment$overall_risk_score < 0.2) {
    risk_assessment$risk_category <- "Low"
  } else if (risk_assessment$overall_risk_score < 0.4) {
    risk_assessment$risk_category <- "Moderate"
  } else if (risk_assessment$overall_risk_score < 0.6) {
    risk_assessment$risk_category <- "High"
  } else {
    risk_assessment$risk_category <- "Very High"
  }
  
  return(risk_assessment)
}

# ================================================================================
# 5. DECISION SUPPORT UNDER UNCERTAINTY
# ================================================================================

#' Generate probabilistic recommendations with confidence intervals
generate_probabilistic_recommendations <- function(uncertainty_results, confidence_levels = c(0.5, 0.8, 0.95)) {
  
  recommendations <- list()
  
  # Extract statistics
  fert_stats <- uncertainty_results$fertilizer_recommendations
  yield_stats <- uncertainty_results$yield_predictions
  econ_stats <- uncertainty_results$economic_analysis
  
  # Generate recommendations for each confidence level
  for (conf_level in confidence_levels) {
    
    alpha <- 1 - conf_level
    lower_q <- alpha / 2
    upper_q <- 1 - alpha / 2
    
    # Get quantile names
    lower_name <- paste0("q", sprintf("%03d", round(lower_q * 1000)))
    upper_name <- paste0("q", sprintf("%03d", round(upper_q * 1000)))
    
    if (lower_name == "q250") lower_name <- "q025"
    if (upper_name == "q750") upper_name <- "q975"
    if (lower_name == "q100") lower_name <- "q05"
    if (upper_name == "q900") upper_name <- "q95"
    
    recommendation <- list(
      confidence_level = conf_level,
      fertilizer_rates = list(
        N = list(
          median = fert_stats$N$median,
          lower_ci = fert_stats$N[[lower_name]],
          upper_ci = fert_stats$N[[upper_name]]
        ),
        P = list(
          median = fert_stats$P$median,
          lower_ci = fert_stats$P[[lower_name]],
          upper_ci = fert_stats$P[[upper_name]]
        ),
        K = list(
          median = fert_stats$K$median,
          lower_ci = fert_stats$K[[lower_name]],
          upper_ci = fert_stats$K[[upper_name]]
        )
      ),
      expected_yield = list(
        median = yield_stats$predicted$median,
        lower_ci = yield_stats$predicted[[lower_name]],
        upper_ci = yield_stats$predicted[[upper_name]]
      )
    )
    
    if (!is.null(econ_stats)) {
      recommendation$economic_return <- list(
        median = econ_stats$median_return,
        lower_ci = econ_stats[[lower_name]],
        upper_ci = econ_stats[[upper_name]]
      )
    }
    
    recommendations[[paste0("conf_", round(conf_level * 100))]] <- recommendation
  }
  
  return(recommendations)
}

#' Make decision recommendation based on uncertainty analysis
make_uncertainty_based_decision <- function(uncertainty_results, risk_tolerance = "moderate") {
  
  decision <- list()
  
  # Extract key metrics
  success_prob <- uncertainty_results$success_probability
  risk_score <- uncertainty_results$risk_assessment$overall_risk_score
  econ_stats <- uncertainty_results$economic_analysis
  
  # Risk tolerance thresholds
  risk_thresholds <- list(
    "conservative" = 0.3,
    "moderate" = 0.5,
    "aggressive" = 0.7
  )
  
  threshold <- risk_thresholds[[risk_tolerance]]
  
  # Economic decision if data available
  if (!is.null(econ_stats)) {
    prob_profit <- econ_stats$prob_profit
    expected_return <- econ_stats$mean_return
    
    if (prob_profit >= 0.6 && expected_return > 0 && risk_score <= threshold) {
      decision$recommendation <- "APPLY_FERTILIZER"
      decision$confidence <- "HIGH"
    } else if (prob_profit >= 0.4 && expected_return > -50 && risk_score <= threshold) {
      decision$recommendation <- "APPLY_FERTILIZER_CAUTIOUSLY"
      decision$confidence <- "MEDIUM"
    } else {
      decision$recommendation <- "DO_NOT_APPLY"
      decision$confidence <- "LOW"
    }
    
    decision$economic_justification <- list(
      probability_of_profit = prob_profit,
      expected_return = expected_return,
      risk_score = risk_score
    )
  } else {
    # Agronomic decision based on success probability
    if (success_prob >= 0.7 && risk_score <= threshold) {
      decision$recommendation <- "APPLY_FERTILIZER"
      decision$confidence <- "HIGH"
    } else if (success_prob >= 0.5 && risk_score <= threshold) {
      decision$recommendation <- "APPLY_FERTILIZER_CAUTIOUSLY"
      decision$confidence <- "MEDIUM"
    } else {
      decision$recommendation <- "COLLECT_MORE_DATA"
      decision$confidence <- "LOW"
    }
    
    decision$agronomic_justification <- list(
      success_probability = success_prob,
      risk_score = risk_score
    )
  }
  
  # Add rationale
  decision$rationale <- generate_decision_rationale(decision, uncertainty_results)
  
  return(decision)
}

#' Generate rationale for decision
generate_decision_rationale <- function(decision, uncertainty_results) {
  
  rationale <- c()
  
  if (decision$recommendation == "APPLY_FERTILIZER") {
    rationale <- c(rationale, 
      "High probability of successful yield response",
      "Economic analysis indicates profitable investment",
      "Risk level is acceptable for given data quality"
    )
  } else if (decision$recommendation == "APPLY_FERTILIZER_CAUTIOUSLY") {
    rationale <- c(rationale,
      "Moderate probability of success with some uncertainty",
      "Consider reduced fertilizer rates or split applications",
      "Monitor response and adjust future applications"
    )
  } else if (decision$recommendation == "DO_NOT_APPLY") {
    rationale <- c(rationale,
      "Low probability of economic benefit",
      "High risk of loss given current data quality",
      "Consider improving soil data before fertilizer investment"
    )
  } else if (decision$recommendation == "COLLECT_MORE_DATA") {
    rationale <- c(rationale,
      "Uncertainty too high for confident recommendation",
      "Additional soil data would significantly improve decision quality",
      "Consider field testing or laboratory analysis"
    )
  }
  
  # Add data quality context
  data_quality <- uncertainty_results$metadata$data_quality
  if (data_quality == "global_maps") {
    rationale <- c(rationale,
      "Recommendation based on global soil maps - local verification recommended"
    )
  } else if (data_quality == "regional_refined") {
    rationale <- c(rationale,
      "Regional calibration applied - moderate confidence in recommendation"
    )
  } else if (data_quality == "field_observed") {
    rationale <- c(rationale,
      "Field observations included - good confidence in recommendation"
    )
  } else if (data_quality == "laboratory_analyzed") {
    rationale <- c(rationale,
      "Based on laboratory analysis - high confidence in recommendation"
    )
  }
  
  return(rationale)
}

# ================================================================================
# 6. SENSITIVITY ANALYSIS
# ================================================================================

#' Perform sensitivity analysis to identify most important parameters
perform_sensitivity_analysis <- function(soil_data, crop_name, target_yield, 
                                       parameters = c("pH", "SOC", "Olsen_P", "Exch_K")) {
  
  cat("Performing sensitivity analysis...\n")
  
  # Base case calculation
  base_result <- calculate_fertilizer_needs(soil_data, crop_name, target_yield)
  base_yield <- base_result$fertilizer_recommendation$predicted_yield
  
  sensitivity_results <- list()
  
  # Test each parameter
  for (param in parameters) {
    
    cat("Analyzing sensitivity to", param, "...\n")
    
    # Define parameter ranges (±20% around base value)
    base_value <- soil_data[[param]]
    if (is.null(base_value)) next
    
    if (param == "pH") {
      # pH uses additive changes
      test_values <- base_value + c(-0.5, -0.3, -0.1, 0.1, 0.3, 0.5)
      test_values <- pmax(3.5, pmin(8.5, test_values))  # Realistic bounds
    } else {
      # Other parameters use multiplicative changes
      multipliers <- c(0.6, 0.8, 0.9, 1.1, 1.3, 1.5)
      test_values <- base_value * multipliers
    }
    
    # Test each value
    yield_responses <- numeric(length(test_values))
    
    for (i in seq_along(test_values)) {
      # Create modified soil data
      modified_soil <- soil_data
      modified_soil[[param]] <- test_values[i]
      
      tryCatch({
        # Calculate response
        result <- calculate_fertilizer_needs(modified_soil, crop_name, target_yield)
        yield_responses[i] <- result$fertilizer_recommendation$predicted_yield
      }, error = function(e) {
        yield_responses[i] <- NA
      })
    }
    
    # Calculate sensitivity metrics
    valid_indices <- !is.na(yield_responses)
    if (sum(valid_indices) >= 3) {
      sensitivity_results[[param]] <- list(
        parameter_values = test_values[valid_indices],
        yield_responses = yield_responses[valid_indices],
        sensitivity_slope = calculate_sensitivity_slope(test_values[valid_indices], 
                                                       yield_responses[valid_indices], 
                                                       base_value),
        relative_sensitivity = sd(yield_responses[valid_indices], na.rm = TRUE) / base_yield
      )
    }
  }
  
  # Rank parameters by sensitivity
  sensitivities <- sapply(sensitivity_results, function(x) x$relative_sensitivity)
  sensitivity_ranking <- names(sort(sensitivities, decreasing = TRUE))
  
  return(list(
    base_yield = base_yield,
    parameter_sensitivities = sensitivity_results,
    sensitivity_ranking = sensitivity_ranking,
    most_sensitive = sensitivity_ranking[1],
    least_sensitive = tail(sensitivity_ranking, 1)
  ))
}

#' Calculate sensitivity slope
calculate_sensitivity_slope <- function(param_values, responses, base_value) {
  
  # Fit linear model
  model <- lm(responses ~ param_values)
  slope <- coef(model)[2]
  
  # Convert to relative sensitivity (% change in yield per % change in parameter)
  base_response <- predict(model, newdata = data.frame(param_values = base_value))
  relative_slope <- (slope * base_value) / base_response
  
  return(relative_slope)
}

# ================================================================================
# 7. REPORTING AND VISUALIZATION
# ================================================================================

#' Generate comprehensive uncertainty report
generate_uncertainty_report <- function(uncertainty_results, probabilistic_recs, decision, 
                                       sensitivity_analysis = NULL) {
  
  cat("\n=== UNCERTAINTY ANALYSIS REPORT ===\n")
  cat("Analysis Date:", format(uncertainty_results$metadata$simulation_date), "\n")
  cat("Data Quality:", uncertainty_results$metadata$data_quality, "\n")
  cat("Uncertainty Tier:", uncertainty_results$metadata$uncertainty_tier, "\n")
  cat("Valid Simulations:", uncertainty_results$n_valid_simulations, "\n\n")
  
  # Probabilistic recommendations
  cat("--- PROBABILISTIC FERTILIZER RECOMMENDATIONS ---\n")
  conf_80 <- probabilistic_recs$conf_80
  
  cat("Fertilizer Rates (80% Confidence Intervals):\n")
  cat(sprintf("  Nitrogen (N): %.1f kg/ha [%.1f - %.1f]\n", 
              conf_80$fertilizer_rates$N$median,
              conf_80$fertilizer_rates$N$lower_ci,
              conf_80$fertilizer_rates$N$upper_ci))
  cat(sprintf("  Phosphorus (P): %.1f kg/ha [%.1f - %.1f]\n", 
              conf_80$fertilizer_rates$P$median,
              conf_80$fertilizer_rates$P$lower_ci,
              conf_80$fertilizer_rates$P$upper_ci))
  cat(sprintf("  Potassium (K): %.1f kg/ha [%.1f - %.1f]\n", 
              conf_80$fertilizer_rates$K$median,
              conf_80$fertilizer_rates$K$lower_ci,
              conf_80$fertilizer_rates$K$upper_ci))
  
  cat(sprintf("\nExpected Yield: %.0f kg/ha [%.0f - %.0f]\n",
              conf_80$expected_yield$median,
              conf_80$expected_yield$lower_ci,
              conf_80$expected_yield$upper_ci))
  
  # Success probability
  cat(sprintf("Probability of Target Achievement: %.1f%%\n", 
              uncertainty_results$success_probability * 100))
  
  # Economic analysis
  if (!is.null(uncertainty_results$economic_analysis)) {
    econ <- uncertainty_results$economic_analysis
    cat(sprintf("\nEconomic Return: $%.0f [%.0f - %.0f]\n",
                econ$median_return, econ$q025, econ$q975))
    cat(sprintf("Probability of Profit: %.1f%%\n", econ$prob_profit * 100))
  }
  
  # Risk assessment
  cat("\n--- RISK ASSESSMENT ---\n")
  risk <- uncertainty_results$risk_assessment
  cat("Overall Risk Category:", risk$risk_category, "\n")
  cat(sprintf("Risk Score: %.2f (0=low, 1=high)\n", risk$overall_risk_score))
  
  if (!is.null(risk$fertilizer_uncertainty)) {
    cat(sprintf("Fertilizer Rate Uncertainty: %.1f%% CV\n", 
                risk$fertilizer_uncertainty$overall_cv * 100))
  }
  
  if (!is.null(risk$yield_risk)) {
    cat(sprintf("Yield Uncertainty: %.1f%% CV\n", risk$yield_risk$cv * 100))
  }
  
  # Decision recommendation
  cat("\n--- DECISION RECOMMENDATION ---\n")
  cat("Recommendation:", decision$recommendation, "\n")
  cat("Confidence:", decision$confidence, "\n")
  
  cat("\nRationale:\n")
  for (reason in decision$rationale) {
    cat("  -", reason, "\n")
  }
  
  # Sensitivity analysis
  if (!is.null(sensitivity_analysis)) {
    cat("\n--- SENSITIVITY ANALYSIS ---\n")
    cat("Most Sensitive Parameter:", sensitivity_analysis$most_sensitive, "\n")
    cat("Parameter Ranking by Sensitivity:\n")
    for (i in seq_along(sensitivity_analysis$sensitivity_ranking)) {
      param <- sensitivity_analysis$sensitivity_ranking[i]
      sens <- sensitivity_analysis$parameter_sensitivities[[param]]$relative_sensitivity
      cat(sprintf("  %d. %s (%.1f%% relative sensitivity)\n", i, param, sens * 100))
    }
  }
  
  cat("\n=== END UNCERTAINTY REPORT ===\n")
}

cat("✓ Uncertainty Quantification Module loaded successfully\n")
cat("Main function: run_quefts_with_uncertainty(soil_data, crop_name, target_yield, ...)\n")
cat("Supports Monte Carlo simulation, probabilistic recommendations, and risk assessment\n\n")
