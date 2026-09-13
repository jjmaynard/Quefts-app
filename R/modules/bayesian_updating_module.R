# ================================================================================
# BAYESIAN UPDATING MODULE FOR QUEFTS CALCULATION ENGINE
# Implements Bayesian updating to incorporate prior knowledge and new data
# ================================================================================

cat("Loading Bayesian Updating Module for QUEFTS...\n")

# Required libraries
if (!require(mvtnorm, quietly = TRUE)) {
  cat("Warning: mvtnorm package needed for Bayesian updating\n")
}

# ================================================================================
# 1. BAYESIAN PARAMETER UPDATING
# ================================================================================

#' Bayesian updating for soil parameters with new observations
#' 
#' @param prior_params List of prior parameter distributions (mean, variance)
#' @param new_observations List of new observations with uncertainties
#' @param observation_weights Weights for different observation types
#' @return Updated posterior parameter distributions
bayesian_update_soil_parameters <- function(prior_params, new_observations, 
                                           observation_weights = NULL) {
  
  cat("Performing Bayesian updating of soil parameters...\n")
  
  # Default weights if not provided
  if (is.null(observation_weights)) {
    observation_weights <- list(
      global_maps = 0.1,
      regional_surveys = 0.3,
      field_observations = 0.5,
      laboratory_analysis = 1.0
    )
  }
  
  updated_params <- list()
  
  # Parameters to update
  param_names <- c("pH", "SOC", "Kex", "Polsen")
  
  for (param in param_names) {
    if (param %in% names(prior_params) && param %in% names(new_observations)) {
      
      # Prior distribution
      prior_mean <- prior_params[[param]]$mean
      prior_var <- prior_params[[param]]$variance
      prior_precision <- 1 / prior_var
      
      # Likelihood from new observations
      obs_data <- new_observations[[param]]
      
      # Handle multiple observation sources
      if (is.list(obs_data)) {
        # Multiple sources with different reliabilities
        total_precision <- prior_precision
        weighted_mean_sum <- prior_mean * prior_precision
        
        for (source in names(obs_data)) {
          if (source %in% names(observation_weights)) {
            obs_mean <- obs_data[[source]]$value
            obs_var <- obs_data[[source]]$variance
            obs_weight <- observation_weights[[source]]
            
            # Weighted precision and mean contribution
            obs_precision <- obs_weight / obs_var
            total_precision <- total_precision + obs_precision
            weighted_mean_sum <- weighted_mean_sum + obs_mean * obs_precision
          }
        }
        
        # Posterior parameters
        posterior_mean <- weighted_mean_sum / total_precision
        posterior_var <- 1 / total_precision
        
      } else {
        # Single observation
        obs_mean <- obs_data$value
        obs_var <- obs_data$variance
        obs_precision <- 1 / obs_var
        
        # Bayesian updating formulas for conjugate normal-normal model
        posterior_precision <- prior_precision + obs_precision
        posterior_mean <- (prior_mean * prior_precision + obs_mean * obs_precision) / posterior_precision
        posterior_var <- 1 / posterior_precision
      }
      
      updated_params[[param]] <- list(
        prior = list(mean = prior_mean, variance = prior_var),
        posterior = list(mean = posterior_mean, variance = posterior_var),
        uncertainty_reduction = 1 - (posterior_var / prior_var),
        information_gain = log(prior_var / posterior_var) / 2  # KL divergence
      )
      
      cat(sprintf("  %s: %.3f ± %.3f → %.3f ± %.3f (%.1f%% uncertainty reduction)\n",
                  param, prior_mean, sqrt(prior_var), 
                  posterior_mean, sqrt(posterior_var),
                  updated_params[[param]]$uncertainty_reduction * 100))
    }
  }
  
  cat("✓ Bayesian updating completed\n\n")
  return(updated_params)
}

#' Create prior distributions for soil parameters based on data source
#' 
#' @param data_source Source of prior information ("global", "regional", "field")
#' @param location_params Optional location-specific parameters
#' @return Prior parameter distributions
create_soil_parameter_priors <- function(data_source = "global", location_params = NULL) {
  
  # Default priors based on global soil databases
  global_priors <- list(
    pH = list(mean = 6.0, variance = 1.0),      # Global pH range ~4-8
    SOC = list(mean = 20, variance = 400),      # Global SOC range ~5-50 g/kg
    Kex = list(mean = 5, variance = 25),        # Global K range ~1-15 mmol/kg
    Polsen = list(mean = 10, variance = 100)    # Global P range ~2-30 mg/kg
  )
  
  if (data_source == "regional" && !is.null(location_params)) {
    # Refine priors with regional information
    regional_priors <- global_priors
    
    # Example regional adjustments (could be parameterized by region)
    if (!is.null(location_params$climate_zone)) {
      if (location_params$climate_zone == "tropical") {
        regional_priors$pH$mean <- 5.5
        regional_priors$pH$variance <- 0.5
        regional_priors$SOC$mean <- 15
        regional_priors$SOC$variance <- 200
      } else if (location_params$climate_zone == "temperate") {
        regional_priors$pH$mean <- 6.5
        regional_priors$pH$variance <- 0.3
        regional_priors$SOC$mean <- 25
        regional_priors$SOC$variance <- 300
      }
    }
    
    return(regional_priors)
  }
  
  return(global_priors)
}

# ================================================================================
# 2. ENHANCED CONFIDENCE INTERVALS
# ================================================================================

#' Generate comprehensive confidence intervals including 50% level
#' 
#' @param samples Vector of Monte Carlo samples
#' @param confidence_levels Vector of confidence levels (0.5, 0.8, 0.95)
#' @return List of confidence intervals
generate_comprehensive_confidence_intervals <- function(samples, 
                                                       confidence_levels = c(0.5, 0.8, 0.95)) {
  
  intervals <- list()
  
  for (conf_level in confidence_levels) {
    alpha <- 1 - conf_level
    lower_prob <- alpha / 2
    upper_prob <- 1 - alpha / 2
    
    interval_name <- paste0("confidence_", round(conf_level * 100))
    
    intervals[[interval_name]] <- list(
      level = conf_level,
      lower = quantile(samples, lower_prob, na.rm = TRUE),
      upper = quantile(samples, upper_prob, na.rm = TRUE),
      width = quantile(samples, upper_prob, na.rm = TRUE) - quantile(samples, lower_prob, na.rm = TRUE)
    )
  }
  
  # Add complete quantile information
  intervals$quantiles <- list(
    q025 = quantile(samples, 0.025, na.rm = TRUE),
    q05 = quantile(samples, 0.05, na.rm = TRUE),
    q10 = quantile(samples, 0.10, na.rm = TRUE),
    q25 = quantile(samples, 0.25, na.rm = TRUE),
    q50 = quantile(samples, 0.50, na.rm = TRUE),
    q75 = quantile(samples, 0.75, na.rm = TRUE),
    q90 = quantile(samples, 0.90, na.rm = TRUE),
    q95 = quantile(samples, 0.95, na.rm = TRUE),
    q975 = quantile(samples, 0.975, na.rm = TRUE)
  )
  
  return(intervals)
}

# ================================================================================
# 3. ENHANCED QUEFTS CALCULATION WITH BAYESIAN UPDATING
# ================================================================================

#' Enhanced QUEFTS calculation with Bayesian parameter updating
#' 
#' @param soil_data Soil data with multiple sources
#' @param crop Crop parameters
#' @param target_yield Target yield (kg/ha)
#' @param prior_source Source for prior distributions
#' @param update_priors Whether to perform Bayesian updating
#' @param n_simulations Number of Monte Carlo simulations
#' @return Enhanced results with Bayesian updating
calculate_fertilizer_recommendation_bayesian <- function(soil_data, crop, target_yield,
                                                        prior_source = "global",
                                                        update_priors = TRUE,
                                                        n_simulations = 1000) {
  
  cat("=== ENHANCED QUEFTS CALCULATION WITH BAYESIAN UPDATING ===\n")
  
  # Step 1: Create prior distributions
  priors <- create_soil_parameter_priors(prior_source)
  
  # Step 2: Bayesian updating if multiple data sources available
  if (update_priors && "observation_sources" %in% names(soil_data)) {
    cat("STEP 1: Bayesian Parameter Updating\n")
    
    # Structure observations for Bayesian updating
    observations <- list()
    
    if ("pH" %in% names(soil_data)) {
      observations$pH <- list(
        value = soil_data$pH,
        variance = (soil_data$pH * 0.05)^2  # Default 5% uncertainty
      )
    }
    
    if ("SOC" %in% names(soil_data)) {
      observations$SOC <- list(
        value = soil_data$SOC,
        variance = (soil_data$SOC * 0.15)^2  # Default 15% uncertainty
      )
    }
    
    if ("Kex" %in% names(soil_data)) {
      observations$Kex <- list(
        value = soil_data$Kex,
        variance = (soil_data$Kex * 0.20)^2  # Default 20% uncertainty
      )
    }
    
    if ("Polsen" %in% names(soil_data)) {
      observations$Polsen <- list(
        value = soil_data$Polsen,
        variance = (soil_data$Polsen * 0.25)^2  # Default 25% uncertainty
      )
    }
    
    # Perform Bayesian updating
    updated_params <- bayesian_update_soil_parameters(priors, observations)
    
    # Use posterior distributions for uncertainty analysis
    for (param in names(updated_params)) {
      posterior <- updated_params[[param]]$posterior
      soil_data[[paste0(param, "_uncertainty")]] <- sqrt(posterior$variance)
    }
    
  } else {
    cat("STEP 1: Using prior distributions (no Bayesian updating)\n")
    updated_params <- NULL
  }
  
  # Step 2: Enhanced Monte Carlo calculation
  cat("STEP 2: Monte Carlo Simulation with Enhanced Confidence Intervals\n")
  
  # Check if enhanced calculation engine is available
  if (exists("calculate_fertilizer_recommendation")) {
    # Use enhanced engine
    standard_result <- calculate_fertilizer_recommendation(
      soil_data = soil_data,
      crop = crop,
      target_yield = target_yield,
      uncertainty_level = "medium",
      n_simulations = n_simulations
    )
    
    # Enhance with additional confidence intervals
    enhanced_fertilizer_rates <- list()
    enhanced_yield_prediction <- list()
    
    # Get raw samples if available
    if ("detailed_results" %in% names(standard_result)) {
      detailed <- standard_result$detailed_results
      
      # Enhanced fertilizer rate intervals
      enhanced_fertilizer_rates$N <- generate_comprehensive_confidence_intervals(
        detailed$fertilizer_rates$N$samples
      )
      enhanced_fertilizer_rates$P <- generate_comprehensive_confidence_intervals(
        detailed$fertilizer_rates$P$samples
      )
      enhanced_fertilizer_rates$K <- generate_comprehensive_confidence_intervals(
        detailed$fertilizer_rates$K$samples
      )
      
      # Enhanced yield prediction intervals
      enhanced_yield_prediction <- generate_comprehensive_confidence_intervals(
        detailed$yield_predictions$samples
      )
    }
    
  } else {
    stop("Enhanced calculation engine not available. Load quefts_calculation_engine.R first.")
  }
  
  # Step 3: Compile enhanced results
  enhanced_results <- list(
    # Standard results
    standard_results = standard_result,
    
    # Bayesian updating results
    bayesian_updating = updated_params,
    
    # Enhanced confidence intervals
    enhanced_confidence_intervals = list(
      fertilizer_rates = enhanced_fertilizer_rates,
      yield_prediction = enhanced_yield_prediction
    ),
    
    # Prior information
    prior_information = priors,
    
    # Metadata
    calculation_method = "Bayesian Enhanced QUEFTS",
    prior_source = prior_source,
    bayesian_updating_applied = update_priors,
    n_simulations = n_simulations,
    calculation_date = Sys.time()
  )
  
  cat("✓ Bayesian enhanced calculation completed\n\n")
  
  return(enhanced_results)
}

# ================================================================================
# 4. ENHANCED SENSITIVITY ANALYSIS WITH BAYESIAN COMPONENTS
# ================================================================================

#' Enhanced sensitivity analysis including Bayesian information gain
#' 
#' @param soil_data Soil data with uncertainties
#' @param crop_name Crop name
#' @param target_yield Target yield
#' @param include_bayesian Whether to include Bayesian sensitivity metrics
#' @return Enhanced sensitivity analysis results
perform_enhanced_sensitivity_analysis <- function(soil_data, crop_name, target_yield,
                                                  include_bayesian = TRUE) {
  
  cat("Performing enhanced sensitivity analysis...\n")
  
  # Check if standard sensitivity analysis is available
  if (exists("perform_sensitivity_analysis")) {
    standard_sensitivity <- perform_sensitivity_analysis(soil_data, crop_name, target_yield)
  } else {
    cat("Warning: Standard sensitivity analysis not available\n")
    standard_sensitivity <- NULL
  }
  
  # Enhanced Bayesian sensitivity analysis
  if (include_bayesian) {
    cat("Calculating Bayesian sensitivity metrics...\n")
    
    # Value of Information (VOI) analysis
    voi_analysis <- calculate_value_of_information(soil_data, crop_name, target_yield)
    
    # Expected Value of Perfect Information (EVPI)
    evpi_results <- calculate_evpi(soil_data, crop_name, target_yield)
    
    bayesian_sensitivity <- list(
      value_of_information = voi_analysis,
      expected_value_perfect_info = evpi_results
    )
  } else {
    bayesian_sensitivity <- NULL
  }
  
  enhanced_results <- list(
    standard_sensitivity = standard_sensitivity,
    bayesian_sensitivity = bayesian_sensitivity,
    combined_ranking = combine_sensitivity_rankings(standard_sensitivity, bayesian_sensitivity)
  )
  
  return(enhanced_results)
}

#' Calculate Value of Information for soil parameters
calculate_value_of_information <- function(soil_data, crop_name, target_yield) {
  
  # This is a simplified VOI calculation
  # In practice, this would involve more complex economic modeling
  
  parameters <- c("pH", "SOC", "Kex", "Polsen")
  voi_results <- list()
  
  for (param in parameters) {
    if (param %in% names(soil_data)) {
      # Calculate expected loss under current uncertainty
      current_uncertainty <- soil_data[[paste0(param, "_uncertainty")]] %||% (soil_data[[param]] * 0.2)
      
      # Estimate economic value of reducing uncertainty
      # This is a simplified calculation - would need more sophisticated economic model
      base_fertilizer_cost <- 100  # USD/ha baseline
      uncertainty_cost_factor <- current_uncertainty / soil_data[[param]]
      
      voi_results[[param]] <- list(
        current_uncertainty = current_uncertainty,
        uncertainty_cost_factor = uncertainty_cost_factor,
        estimated_voi = base_fertilizer_cost * uncertainty_cost_factor * 0.1  # 10% cost factor
      )
    }
  }
  
  return(voi_results)
}

#' Calculate Expected Value of Perfect Information
calculate_evpi <- function(soil_data, crop_name, target_yield) {
  
  # Simplified EVPI calculation
  # This would typically involve optimization under uncertainty
  
  # Estimate current expected value under uncertainty
  current_uncertainty <- sqrt(mean(c(
    (soil_data$pH * 0.05)^2,
    (soil_data$SOC * 0.15)^2,
    (soil_data$Kex * 0.20)^2,
    (soil_data$Polsen * 0.25)^2
  ), na.rm = TRUE))
  
  # Economic parameters (simplified)
  expected_yield_gain <- target_yield * 0.2  # 20% potential gain
  crop_price <- 0.30  # USD/kg
  current_loss_due_to_uncertainty <- expected_yield_gain * crop_price * (current_uncertainty / 6.0)  # Normalized
  
  evpi <- current_loss_due_to_uncertainty
  
  return(list(
    evpi_estimate = evpi,
    current_uncertainty = current_uncertainty,
    potential_yield_gain = expected_yield_gain,
    uncertainty_cost = current_loss_due_to_uncertainty
  ))
}

#' Combine sensitivity rankings from different methods
combine_sensitivity_rankings <- function(standard_sensitivity, bayesian_sensitivity) {
  
  if (is.null(standard_sensitivity) && is.null(bayesian_sensitivity)) {
    return(NULL)
  }
  
  combined_ranking <- list()
  
  if (!is.null(standard_sensitivity)) {
    combined_ranking$standard_ranking <- standard_sensitivity$sensitivity_ranking
  }
  
  if (!is.null(bayesian_sensitivity)) {
    # Extract VOI-based ranking
    voi_values <- sapply(bayesian_sensitivity$value_of_information, function(x) x$estimated_voi)
    voi_ranking <- names(sort(voi_values, decreasing = TRUE))
    combined_ranking$voi_ranking <- voi_ranking
  }
  
  return(combined_ranking)
}

# ================================================================================
# 5. UTILITY FUNCTIONS
# ================================================================================

# Null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

# ================================================================================
# MODULE INITIALIZATION
# ================================================================================

cat("✓ Bayesian Updating Module loaded successfully\n")
cat("Enhanced functions available:\n")
cat("- bayesian_update_soil_parameters(): Update parameters with new observations\n")
cat("- calculate_fertilizer_recommendation_bayesian(): Enhanced calculation with Bayesian updating\n")
cat("- generate_comprehensive_confidence_intervals(): 50%, 80%, 95% confidence intervals\n")
cat("- perform_enhanced_sensitivity_analysis(): Enhanced sensitivity analysis\n\n")

cat("Confidence intervals now include:\n")
cat("• 50% confidence intervals (25th-75th percentiles)\n")
cat("• 80% confidence intervals (10th-90th percentiles)\n")
cat("• 95% confidence intervals (2.5th-97.5th percentiles)\n")
cat("• Complete quantile information (q025, q05, q10, q25, q50, q75, q90, q95, q975)\n\n")
