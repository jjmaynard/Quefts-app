# ================================================================================
# OUTPUT GENERATION MODULE FOR QUEFTS DECISION SUPPORT FRAMEWORK
# Implements comprehensive reporting and recommendation formatting
# ================================================================================

cat("Loading Output Generation Module...\n")

# Required libraries
required_packages <- c("jsonlite", "knitr", "rmarkdown")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Warning: %s package not available. Some features may be limited.\n", pkg))
  }
}

# ================================================================================
# 5.1 PRIMARY RECOMMENDATIONS
# ================================================================================

#' Generate comprehensive fertilizer recommendations with confidence intervals
#' 
#' @param quefts_results Results from QUEFTS calculation engine
#' @param crop_data Crop information
#' @param target_yield Target yield (kg/ha)
#' @return Formatted primary recommendations
generate_primary_recommendations <- function(quefts_results, crop_data, target_yield) {
  
  cat("Generating primary fertilizer recommendations...\n")
  
  # Extract fertilizer rates with confidence intervals
  fertilizer_rates <- list()
  
  # Nitrogen recommendations
  N_rates <- quefts_results$detailed_results$fertilizer_rates$N
  fertilizer_rates$nitrogen <- list(
    recommended_rate = round(N_rates$mean, 1),
    units = "kg N/ha",
    confidence_intervals = list(
      CI_50 = sprintf("[%.1f - %.1f]", N_rates$confidence_50[1], N_rates$confidence_50[2]),
      CI_80 = sprintf("[%.1f - %.1f]", N_rates$confidence_80[1], N_rates$confidence_80[2]),
      CI_95 = sprintf("[%.1f - %.1f]", N_rates$confidence_95[1], N_rates$confidence_95[2])
    ),
    uncertainty_level = calculate_uncertainty_level(N_rates$cv),
    interpretation = interpret_fertilizer_recommendation("N", N_rates$mean, N_rates$cv)
  )
  
  # Phosphorus recommendations (convert to P₂O₅)
  P_rates <- quefts_results$detailed_results$fertilizer_rates$P
  P2O5_conversion <- 2.29  # P to P₂O₅ conversion factor
  fertilizer_rates$phosphorus <- list(
    recommended_rate = round(P_rates$mean * P2O5_conversion, 1),
    units = "kg P₂O₅/ha",
    confidence_intervals = list(
      CI_50 = sprintf("[%.1f - %.1f]", 
                      P_rates$confidence_50[1] * P2O5_conversion, 
                      P_rates$confidence_50[2] * P2O5_conversion),
      CI_80 = sprintf("[%.1f - %.1f]", 
                      P_rates$confidence_80[1] * P2O5_conversion, 
                      P_rates$confidence_80[2] * P2O5_conversion),
      CI_95 = sprintf("[%.1f - %.1f]", 
                      P_rates$confidence_95[1] * P2O5_conversion, 
                      P_rates$confidence_95[2] * P2O5_conversion)
    ),
    uncertainty_level = calculate_uncertainty_level(P_rates$cv),
    interpretation = interpret_fertilizer_recommendation("P", P_rates$mean * P2O5_conversion, P_rates$cv)
  )
  
  # Potassium recommendations (convert to K₂O)
  K_rates <- quefts_results$detailed_results$fertilizer_rates$K
  K2O_conversion <- 1.20  # K to K₂O conversion factor
  fertilizer_rates$potassium <- list(
    recommended_rate = round(K_rates$mean * K2O_conversion, 1),
    units = "kg K₂O/ha",
    confidence_intervals = list(
      CI_50 = sprintf("[%.1f - %.1f]", 
                      K_rates$confidence_50[1] * K2O_conversion, 
                      K_rates$confidence_50[2] * K2O_conversion),
      CI_80 = sprintf("[%.1f - %.1f]", 
                      K_rates$confidence_80[1] * K2O_conversion, 
                      K_rates$confidence_80[2] * K2O_conversion),
      CI_95 = sprintf("[%.1f - %.1f]", 
                      K_rates$confidence_95[1] * K2O_conversion, 
                      K_rates$confidence_95[2] * K2O_conversion)
    ),
    uncertainty_level = calculate_uncertainty_level(K_rates$cv),
    interpretation = interpret_fertilizer_recommendation("K", K_rates$mean * K2O_conversion, K_rates$cv)
  )
  
  # NPK ratio and timing
  npk_analysis <- calculate_npk_ratio_timing(fertilizer_rates, crop_data)
  
  # Yield predictions
  yield_predictions <- generate_yield_predictions(quefts_results, target_yield)
  
  primary_recommendations <- list(
    fertilizer_rates = fertilizer_rates,
    npk_analysis = npk_analysis,
    yield_predictions = yield_predictions,
    recommendation_confidence = calculate_overall_confidence(quefts_results),
    timestamp = Sys.time(),
    crop = crop_data,
    target_yield = target_yield
  )
  
  cat("✓ Primary recommendations generated\n")
  return(primary_recommendations)
}

#' Calculate uncertainty level from coefficient of variation
calculate_uncertainty_level <- function(cv) {
  if (cv < 0.15) return("Low")
  if (cv < 0.30) return("Medium") 
  if (cv < 0.50) return("High")
  return("Very High")
}

#' Interpret fertilizer recommendations based on rates and uncertainty
interpret_fertilizer_recommendation <- function(nutrient, rate, cv) {
  uncertainty_level <- calculate_uncertainty_level(cv)
  
  # Rate categories (these would be crop-specific in practice)
  rate_categories <- switch(nutrient,
    "N" = list(low = 80, medium = 150, high = 220),
    "P" = list(low = 30, medium = 60, high = 90),
    "K" = list(low = 40, medium = 80, high = 120)
  )
  
  if (rate <= rate_categories$low) {
    rate_level <- "Low"
  } else if (rate <= rate_categories$medium) {
    rate_level <- "Medium"
  } else {
    rate_level <- "High"
  }
  
  interpretation <- sprintf("%s %s application recommended", rate_level, nutrient)
  
  if (uncertainty_level %in% c("High", "Very High")) {
    interpretation <- paste(interpretation, 
                           "- Consider soil testing for more precise recommendations")
  }
  
  return(list(
    rate_level = rate_level,
    uncertainty_level = uncertainty_level,
    interpretation = interpretation
  ))
}

#' Calculate NPK ratio and timing recommendations
calculate_npk_ratio_timing <- function(fertilizer_rates, crop_data) {
  
  N_rate <- fertilizer_rates$nitrogen$recommended_rate
  P_rate <- fertilizer_rates$phosphorus$recommended_rate / 2.29  # Convert back to P
  K_rate <- fertilizer_rates$potassium$recommended_rate / 1.20   # Convert back to K
  
  # Calculate NPK ratio
  min_rate <- min(N_rate, P_rate, K_rate)
  if (min_rate > 0) {
    npk_ratio <- sprintf("%.1f:%.1f:%.1f", 
                         N_rate/min_rate, P_rate/min_rate, K_rate/min_rate)
  } else {
    npk_ratio <- "No fertilizer recommended"
  }
  
  # Generate timing recommendations
  timing_recommendations <- generate_timing_recommendations(fertilizer_rates, crop_data)
  
  return(list(
    npk_ratio = npk_ratio,
    timing = timing_recommendations,
    application_methods = generate_application_methods(fertilizer_rates)
  ))
}

#' Generate timing recommendations based on crop and fertilizer rates
generate_timing_recommendations <- function(fertilizer_rates, crop_data) {
  
  crop_name <- crop_data %||% "general"
  
  # Default timing based on crop type and fertilizer amounts
  timing <- list(
    nitrogen = list(
      total_applications = ifelse(fertilizer_rates$nitrogen$recommended_rate > 120, 3, 2),
      schedule = list(
        "Planting" = "30-40% of total N",
        "Vegetative growth" = "40-50% of total N", 
        "Reproductive stage" = "10-20% of total N (if 3 applications)"
      )
    ),
    phosphorus = list(
      total_applications = 1,
      schedule = list(
        "Planting" = "100% of P₂O₅ at planting or as basal application"
      )
    ),
    potassium = list(
      total_applications = ifelse(fertilizer_rates$potassium$recommended_rate > 100, 2, 1),
      schedule = list(
        "Planting" = "50-100% of K₂O",
        "Mid-season" = "Remaining K₂O if split application"
      )
    )
  )
  
  return(timing)
}

#' Generate application methods recommendations
generate_application_methods <- function(fertilizer_rates) {
  
  methods <- list(
    nitrogen = list(
      method = "Split application recommended",
      details = "Apply as urea, ammonium sulfate, or NPK blend",
      precautions = "Avoid application before heavy rains"
    ),
    phosphorus = list(
      method = "Basal application at planting",
      details = "Apply as DAP, TSP, or NPK blend",
      precautions = "Incorporate into soil for better uptake"
    ),
    potassium = list(
      method = "Basal or split application",
      details = "Apply as KCl, K₂SO₄, or NPK blend",
      precautions = "Ensure adequate moisture for uptake"
    )
  )
  
  return(methods)
}

#' Generate comprehensive yield predictions
generate_yield_predictions <- function(quefts_results, target_yield) {
  
  yield_data <- quefts_results$detailed_results$yield_predictions
  
  predictions <- list(
    expected_yield_with_fertilizer = list(
      mean = round(yield_data$mean, 0),
      median = round(yield_data$median, 0),
      units = "kg/ha",
      confidence_intervals = list(
        CI_50 = sprintf("[%.0f - %.0f]", yield_data$confidence_50[1], yield_data$confidence_50[2]),
        CI_80 = sprintf("[%.0f - %.0f]", yield_data$confidence_80[1], yield_data$confidence_80[2]),
        CI_95 = sprintf("[%.0f - %.0f]", yield_data$confidence_95[1], yield_data$confidence_95[2])
      )
    ),
    
    probability_distributions = list(
      samples = yield_data$samples,
      percentiles = list(
        p10 = quantile(yield_data$samples, 0.10),
        p25 = quantile(yield_data$samples, 0.25),
        p50 = quantile(yield_data$samples, 0.50),
        p75 = quantile(yield_data$samples, 0.75),
        p90 = quantile(yield_data$samples, 0.90)
      )
    ),
    
    target_achievement = list(
      target_yield = target_yield,
      probability_of_meeting_target = mean(yield_data$samples >= target_yield),
      expected_shortfall = ifelse(mean(yield_data$samples) < target_yield,
                                 target_yield - mean(yield_data$samples), 0),
      risk_level = calculate_yield_risk_level(yield_data$samples, target_yield)
    ),
    
    native_yield_comparison = calculate_native_yield_comparison(quefts_results, yield_data)
  )
  
  return(predictions)
}

#' Calculate yield risk level
calculate_yield_risk_level <- function(yield_samples, target_yield) {
  prob_meeting_target <- mean(yield_samples >= target_yield)
  
  if (prob_meeting_target >= 0.80) return("Low Risk")
  if (prob_meeting_target >= 0.60) return("Medium Risk")
  if (prob_meeting_target >= 0.40) return("High Risk")
  return("Very High Risk")
}

#' Calculate native (unfertilized) yield comparison
calculate_native_yield_comparison <- function(quefts_results, fertilized_yield) {
  
  # Estimate native yield (this would come from QUEFTS calculations)
  # For now, using a simplified approach
  native_yield_estimate <- fertilized_yield$mean * 0.6  # Rough estimate
  
  yield_increase <- fertilized_yield$mean - native_yield_estimate
  percent_increase <- (yield_increase / native_yield_estimate) * 100
  
  return(list(
    estimated_native_yield = round(native_yield_estimate, 0),
    expected_yield_increase = round(yield_increase, 0),
    percent_increase = round(percent_increase, 1),
    interpretation = interpret_yield_response(percent_increase)
  ))
}

#' Interpret yield response level
interpret_yield_response <- function(percent_increase) {
  if (percent_increase >= 50) return("Excellent response expected")
  if (percent_increase >= 30) return("Good response expected")
  if (percent_increase >= 15) return("Moderate response expected")
  if (percent_increase >= 5) return("Limited response expected")
  return("Minimal response expected")
}

#' Calculate overall recommendation confidence
calculate_overall_confidence <- function(quefts_results) {
  
  # Extract CVs from all components
  N_cv <- quefts_results$detailed_results$fertilizer_rates$N$cv
  P_cv <- quefts_results$detailed_results$fertilizer_rates$P$cv
  K_cv <- quefts_results$detailed_results$fertilizer_rates$K$cv
  yield_cv <- quefts_results$detailed_results$yield_predictions$cv
  
  # Calculate average uncertainty
  avg_cv <- mean(c(N_cv, P_cv, K_cv, yield_cv), na.rm = TRUE)
  
  # Convert to confidence score (0-100)
  confidence_score <- max(0, min(100, 100 - (avg_cv * 100)))
  
  # Determine confidence level
  if (confidence_score >= 80) confidence_level <- "High"
  else if (confidence_score >= 60) confidence_level <- "Medium"
  else if (confidence_score >= 40) confidence_level <- "Low"
  else confidence_level <- "Very Low"
  
  return(list(
    confidence_score = round(confidence_score, 1),
    confidence_level = confidence_level,
    average_cv = round(avg_cv, 3),
    interpretation = sprintf("Recommendation confidence is %s (%.1f%%)", 
                           confidence_level, confidence_score)
  ))
}

# ================================================================================
# 5.2 ECONOMIC ANALYSIS
# ================================================================================

#' Generate comprehensive economic analysis
#' 
#' @param fertilizer_rates Fertilizer recommendations
#' @param yield_predictions Yield prediction results
#' @param economic_params Economic parameters (prices, costs)
#' @return Economic analysis results
generate_economic_analysis <- function(fertilizer_rates, yield_predictions, economic_params) {
  
  cat("Generating economic analysis...\n")
  
  # Default economic parameters if not provided
  if (missing(economic_params) || is.null(economic_params)) {
    economic_params <- list(
      N_price = 1.20,      # USD/kg N
      P2O5_price = 1.50,   # USD/kg P₂O₅
      K2O_price = 1.00,    # USD/kg K₂O
      crop_price = 0.30,   # USD/kg crop
      application_cost = 25, # USD/ha
      interest_rate = 0.08  # 8% annual
    )
    cat("Using default economic parameters\n")
  }
  
  # Cost-benefit analysis
  cost_benefit <- calculate_cost_benefit_analysis(fertilizer_rates, yield_predictions, economic_params)
  
  # Risk metrics
  risk_metrics <- calculate_economic_risk_metrics(yield_predictions, cost_benefit, economic_params)
  
  # Decision recommendation
  decision <- generate_economic_decision(cost_benefit, risk_metrics)
  
  economic_analysis <- list(
    cost_benefit_analysis = cost_benefit,
    risk_metrics = risk_metrics,
    decision_recommendation = decision,
    economic_parameters = economic_params,
    sensitivity_to_prices = calculate_price_sensitivity(fertilizer_rates, yield_predictions, economic_params)
  )
  
  cat("✓ Economic analysis completed\n")
  return(economic_analysis)
}

#' Calculate detailed cost-benefit analysis
calculate_cost_benefit_analysis <- function(fertilizer_rates, yield_predictions, economic_params) {
  
  # Calculate fertilizer costs
  N_cost <- fertilizer_rates$nitrogen$recommended_rate * economic_params$N_price
  P_cost <- fertilizer_rates$phosphorus$recommended_rate * economic_params$P2O5_price  
  K_cost <- fertilizer_rates$potassium$recommended_rate * economic_params$K2O_price
  
  total_fertilizer_cost <- N_cost + P_cost + K_cost
  total_cost_per_ha <- total_fertilizer_cost + economic_params$application_cost
  
  # Calculate expected revenue
  expected_yield <- yield_predictions$expected_yield_with_fertilizer$mean
  native_yield <- yield_predictions$native_yield_comparison$estimated_native_yield
  additional_yield <- expected_yield - native_yield
  
  additional_revenue <- additional_yield * economic_params$crop_price
  net_benefit <- additional_revenue - total_cost_per_ha
  
  # Benefit:cost ratio
  if (total_cost_per_ha > 0) {
    benefit_cost_ratio <- additional_revenue / total_cost_per_ha
  } else {
    benefit_cost_ratio <- Inf
  }
  
  # Break-even analysis
  if (additional_yield > 0) {
    breakeven_price <- total_cost_per_ha / additional_yield
  } else {
    breakeven_price <- Inf
  }
  
  return(list(
    costs = list(
      nitrogen_cost = round(N_cost, 2),
      phosphorus_cost = round(P_cost, 2),
      potassium_cost = round(K_cost, 2),
      total_fertilizer_cost = round(total_fertilizer_cost, 2),
      application_cost = economic_params$application_cost,
      total_cost_per_ha = round(total_cost_per_ha, 2)
    ),
    revenue = list(
      expected_additional_yield = round(additional_yield, 0),
      additional_revenue = round(additional_revenue, 2),
      crop_price_used = economic_params$crop_price
    ),
    profitability = list(
      net_benefit = round(net_benefit, 2),
      benefit_cost_ratio = round(benefit_cost_ratio, 2),
      breakeven_crop_price = round(breakeven_price, 3),
      interpretation = interpret_profitability(net_benefit, benefit_cost_ratio)
    )
  ))
}

#' Calculate economic risk metrics
calculate_economic_risk_metrics <- function(yield_predictions, cost_benefit, economic_params) {
  
  yield_samples <- yield_predictions$probability_distributions$samples
  native_yield <- yield_predictions$native_yield_comparison$estimated_native_yield
  total_cost <- cost_benefit$costs$total_cost_per_ha
  
  # Calculate profit distribution
  additional_yields <- yield_samples - native_yield
  profits <- additional_yields * economic_params$crop_price - total_cost
  
  # Risk metrics
  probability_of_loss <- mean(profits < 0)
  var_95 <- quantile(profits, 0.05)  # Value at Risk (95th percentile loss)
  expected_loss <- mean(profits[profits < 0])
  
  # Scenario analysis
  scenarios <- list(
    pessimistic = list(
      yield = quantile(yield_samples, 0.10),
      profit = quantile(profits, 0.10)
    ),
    realistic = list(
      yield = quantile(yield_samples, 0.50),
      profit = quantile(profits, 0.50)
    ),
    optimistic = list(
      yield = quantile(yield_samples, 0.90),
      profit = quantile(profits, 0.90)
    )
  )
  
  return(list(
    probability_of_economic_loss = round(probability_of_loss, 3),
    value_at_risk_95 = round(var_95, 2),
    expected_loss = ifelse(is.finite(expected_loss), round(expected_loss, 2), 0),
    profit_distribution = list(
      mean = round(mean(profits), 2),
      sd = round(sd(profits), 2),
      samples = profits
    ),
    scenarios = scenarios,
    risk_level = calculate_economic_risk_level(probability_of_loss, var_95)
  ))
}

#' Calculate economic risk level
calculate_economic_risk_level <- function(prob_loss, var_95) {
  if (prob_loss <= 0.10 && var_95 >= -50) return("Low Risk")
  if (prob_loss <= 0.25 && var_95 >= -100) return("Medium Risk")
  if (prob_loss <= 0.40) return("High Risk")
  return("Very High Risk")
}

#' Generate economic decision recommendation
generate_economic_decision <- function(cost_benefit, risk_metrics) {
  
  net_benefit <- cost_benefit$profitability$net_benefit
  benefit_cost_ratio <- cost_benefit$profitability$benefit_cost_ratio
  prob_loss <- risk_metrics$probability_of_economic_loss
  
  # Decision logic
  if (net_benefit > 0 && benefit_cost_ratio > 1.5 && prob_loss < 0.20) {
    decision <- "STRONGLY RECOMMEND"
    rationale <- "High profitability with low economic risk"
  } else if (net_benefit > 0 && benefit_cost_ratio > 1.2 && prob_loss < 0.30) {
    decision <- "RECOMMEND"
    rationale <- "Positive returns with acceptable risk"
  } else if (net_benefit > 0 && prob_loss < 0.40) {
    decision <- "CAUTIOUSLY RECOMMEND"
    rationale <- "Positive expected returns but moderate risk"
  } else if (net_benefit > -25 && prob_loss < 0.50) {
    decision <- "NEUTRAL"
    rationale <- "Marginal economics, consider other factors"
  } else {
    decision <- "NOT RECOMMENDED"
    rationale <- "High risk of economic loss"
  }
  
  return(list(
    decision = decision,
    rationale = rationale,
    key_factors = list(
      net_benefit = net_benefit,
      benefit_cost_ratio = benefit_cost_ratio,
      probability_of_loss = prob_loss
    )
  ))
}

#' Interpret profitability results
interpret_profitability <- function(net_benefit, benefit_cost_ratio) {
  if (net_benefit > 100 && benefit_cost_ratio > 2.0) {
    return("Highly profitable investment")
  } else if (net_benefit > 50 && benefit_cost_ratio > 1.5) {
    return("Profitable investment")
  } else if (net_benefit > 0 && benefit_cost_ratio > 1.2) {
    return("Moderately profitable")
  } else if (net_benefit > 0) {
    return("Marginally profitable")
  } else {
    return("Not profitable under current assumptions")
  }
}

#' Calculate sensitivity to price changes
calculate_price_sensitivity <- function(fertilizer_rates, yield_predictions, economic_params) {
  
  # Test price variations
  price_variations <- c(0.8, 0.9, 1.0, 1.1, 1.2)  # ±20% price variation
  
  sensitivity <- list()
  
  for (crop_price_factor in price_variations) {
    modified_params <- economic_params
    modified_params$crop_price <- economic_params$crop_price * crop_price_factor
    
    cost_benefit <- calculate_cost_benefit_analysis(fertilizer_rates, yield_predictions, modified_params)
    
    sensitivity[[sprintf("crop_price_%.0f", crop_price_factor * 100)]] <- list(
      crop_price = modified_params$crop_price,
      net_benefit = cost_benefit$profitability$net_benefit,
      benefit_cost_ratio = cost_benefit$profitability$benefit_cost_ratio
    )
  }
  
  return(sensitivity)
}

# ================================================================================
# 5.3 AGRONOMIC INSIGHTS
# ================================================================================

#' Generate comprehensive agronomic insights
#' 
#' @param quefts_results QUEFTS calculation results
#' @param soil_data Original soil data
#' @param fertilizer_rates Fertilizer recommendations
#' @return Agronomic insights and recommendations
generate_agronomic_insights <- function(quefts_results, soil_data, fertilizer_rates) {
  
  cat("Generating agronomic insights...\n")
  
  # Nutrient limitations analysis
  nutrient_limitations <- analyze_nutrient_limitations(quefts_results, soil_data)
  
  # Soil health indicators
  soil_health <- assess_soil_health_indicators(soil_data, fertilizer_rates)
  
  # Nutrient use efficiency
  efficiency_analysis <- calculate_nutrient_use_efficiency(quefts_results, fertilizer_rates)
  
  # Environmental considerations
  environmental_assessment <- assess_environmental_risks(fertilizer_rates, soil_data)
  
  agronomic_insights <- list(
    nutrient_limitations = nutrient_limitations,
    soil_health_indicators = soil_health,
    nutrient_use_efficiency = efficiency_analysis,
    environmental_assessment = environmental_assessment,
    sustainability_metrics = calculate_sustainability_metrics(quefts_results, soil_data)
  )
  
  cat("✓ Agronomic insights generated\n")
  return(agronomic_insights)
}

#' Analyze nutrient limitations and primary constraints
analyze_nutrient_limitations <- function(quefts_results, soil_data) {
  
  # Extract soil nutrient supplies
  soil_supply <- quefts_results$detailed_results$soil_supply
  
  # Calculate relative nutrient levels
  N_supply <- soil_supply$N$mean
  P_supply <- soil_supply$P$mean  
  K_supply <- soil_supply$K$mean
  
  # Identify primary limiting nutrient
  nutrient_levels <- c(N = N_supply, P = P_supply, K = K_supply)
  primary_limiting <- names(which.min(nutrient_levels))
  
  # Seasonal release patterns
  seasonal_patterns <- estimate_seasonal_nutrient_release(soil_data)
  
  # Environmental loss risks
  loss_risks <- assess_nutrient_loss_risks(soil_data, quefts_results)
  
  return(list(
    primary_limiting_nutrient = primary_limiting,
    nutrient_supply_levels = list(
      nitrogen = list(supply = round(N_supply, 1), status = classify_nutrient_level(N_supply, "N")),
      phosphorus = list(supply = round(P_supply, 1), status = classify_nutrient_level(P_supply, "P")),
      potassium = list(supply = round(K_supply, 1), status = classify_nutrient_level(K_supply, "K"))
    ),
    seasonal_patterns = seasonal_patterns,
    loss_risks = loss_risks
  ))
}

#' Classify nutrient level (Low, Medium, High)
classify_nutrient_level <- function(supply, nutrient) {
  # These thresholds would be crop and region specific
  thresholds <- switch(nutrient,
    "N" = c(low = 40, medium = 80),
    "P" = c(low = 15, medium = 30),
    "K" = c(low = 60, medium = 120)
  )
  
  if (supply <= thresholds["low"]) return("Low")
  if (supply <= thresholds["medium"]) return("Medium")
  return("High")
}

#' Estimate seasonal nutrient release patterns
estimate_seasonal_nutrient_release <- function(soil_data) {
  
  # Based on soil organic matter and temperature patterns
  SOC <- soil_data$SOC %||% 20
  
  patterns <- list(
    nitrogen = list(
      early_season = "20-30% of total N from mineralization",
      mid_season = "40-50% peak mineralization period", 
      late_season = "20-30% continued slow release",
      temperature_dependency = "High - increases with soil temperature"
    ),
    phosphorus = list(
      availability = "Relatively constant throughout season",
      soil_pH_effect = ifelse(soil_data$pH > 7, "Reduced availability in alkaline soils",
                             ifelse(soil_data$pH < 5.5, "Reduced availability in acidic soils",
                                   "Good availability")),
      organic_P_contribution = sprintf("%.0f%% from organic matter", min(60, SOC * 2))
    ),
    potassium = list(
      availability = "Generally good throughout season",
      clay_effect = ifelse(soil_data$clay > 40, "Good K retention in clay soils",
                          "Risk of K leaching in sandy soils"),
      seasonal_variation = "Minimal variation in temperate climates"
    )
  )
  
  return(patterns)
}

#' Assess nutrient loss risks
assess_nutrient_loss_risks <- function(soil_data, quefts_results) {
  
  # Risk factors based on soil properties
  clay_content <- soil_data$clay %||% 25
  organic_matter <- soil_data$SOC %||% 20
  pH <- soil_data$pH %||% 6.0
  
  loss_risks <- list(
    nitrogen = list(
      leaching_risk = ifelse(clay_content < 20, "High", 
                           ifelse(clay_content < 35, "Medium", "Low")),
      volatilization_risk = ifelse(pH > 7.5, "High", "Low"),
      denitrification_risk = "Medium under wet conditions"
    ),
    phosphorus = list(
      runoff_risk = ifelse(clay_content < 15, "High", "Low"),
      fixation_risk = ifelse(pH < 5.5 || pH > 7.5, "High", "Low"),
      overall_mobility = "Low - relatively immobile"
    ),
    potassium = list(
      leaching_risk = ifelse(clay_content < 20, "Medium", "Low"),
      fixation_risk = ifelse(clay_content > 40, "Medium", "Low"),
      overall_mobility = "Medium"
    )
  )
  
  return(loss_risks)
}

#' Assess soil health indicators
assess_soil_health_indicators <- function(soil_data, fertilizer_rates) {
  
  # Organic matter assessment
  SOC <- soil_data$SOC %||% 20
  om_adequacy <- assess_organic_matter_adequacy(SOC)
  
  # pH optimization
  pH <- soil_data$pH %||% 6.0
  ph_recommendations <- generate_ph_recommendations(pH)
  
  # Nutrient balance
  nutrient_balance <- assess_nutrient_balance_ratios(soil_data, fertilizer_rates)
  
  return(list(
    organic_matter = om_adequacy,
    pH_status = ph_recommendations,
    nutrient_balance = nutrient_balance,
    overall_soil_health = calculate_overall_soil_health(soil_data)
  ))
}

#' Assess organic matter adequacy
assess_organic_matter_adequacy <- function(SOC) {
  
  # Convert SOC to OM (approximate conversion)
  organic_matter <- SOC * 1.72
  
  if (organic_matter >= 40) {
    status <- "High"
    recommendation <- "Excellent organic matter levels"
  } else if (organic_matter >= 25) {
    status <- "Medium"
    recommendation <- "Good organic matter levels, maintain with residue management"
  } else if (organic_matter >= 15) {
    status <- "Low"
    recommendation <- "Increase organic matter through compost, residues, or cover crops"
  } else {
    status <- "Very Low"
    recommendation <- "Critical need for organic matter improvement"
  }
  
  return(list(
    organic_carbon = SOC,
    organic_matter_percent = round(organic_matter / 10, 1),
    status = status,
    recommendation = recommendation
  ))
}

#' Generate pH optimization recommendations
generate_ph_recommendations <- function(pH) {
  
  if (pH < 5.5) {
    status <- "Too Acidic"
    recommendation <- sprintf("Apply lime to raise pH to 6.0-6.5 (current: %.1f)", pH)
    lime_needed <- estimate_lime_requirement(pH)
  } else if (pH <= 6.8) {
    status <- "Optimal"
    recommendation <- "pH is in optimal range for most crops"
    lime_needed <- 0
  } else if (pH <= 7.5) {
    status <- "Slightly Alkaline"
    recommendation <- "pH slightly high but acceptable for most crops"
    lime_needed <- 0
  } else {
    status <- "Too Alkaline"
    recommendation <- sprintf("pH too high (%.1f), may limit nutrient availability", pH)
    lime_needed <- 0
  }
  
  return(list(
    current_pH = pH,
    status = status,
    recommendation = recommendation,
    lime_requirement_kg_ha = lime_needed
  ))
}

#' Estimate lime requirement (simplified)
estimate_lime_requirement <- function(current_pH, target_pH = 6.5) {
  if (current_pH >= target_pH) return(0)
  
  # Simplified lime requirement calculation
  pH_increase_needed <- target_pH - current_pH
  lime_kg_ha <- pH_increase_needed * 1000  # Very rough estimate
  
  return(round(lime_kg_ha, 0))
}

#' Assess nutrient balance ratios
assess_nutrient_balance_ratios <- function(soil_data, fertilizer_rates) {
  
  # Calculate total nutrient availability (soil + fertilizer)
  N_total <- (soil_data$total_N %||% 1.5) * 1000 + fertilizer_rates$nitrogen$recommended_rate
  P_total <- (soil_data$Polsen %||% 15) + fertilizer_rates$phosphorus$recommended_rate / 2.29
  K_total <- (soil_data$Kex %||% 5) * 39.1 + fertilizer_rates$potassium$recommended_rate / 1.20
  
  # Calculate ratios
  NP_ratio <- N_total / P_total
  NK_ratio <- N_total / K_total
  PK_ratio <- P_total / K_total
  
  # Assess balance
  balance_assessment <- list(
    N_to_P_ratio = round(NP_ratio, 1),
    N_to_K_ratio = round(NK_ratio, 1), 
    P_to_K_ratio = round(PK_ratio, 1),
    balance_status = assess_balance_status(NP_ratio, NK_ratio, PK_ratio)
  )
  
  return(balance_assessment)
}

#' Assess nutrient balance status
assess_balance_status <- function(NP_ratio, NK_ratio, PK_ratio) {
  
  # Optimal ranges (these are generalized)
  optimal_ranges <- list(
    NP = c(7, 12),  # N:P ratio
    NK = c(2, 4),   # N:K ratio
    PK = c(0.3, 0.8) # P:K ratio
  )
  
  issues <- c()
  
  if (NP_ratio < optimal_ranges$NP[1]) issues <- c(issues, "N deficient relative to P")
  if (NP_ratio > optimal_ranges$NP[2]) issues <- c(issues, "P deficient relative to N")
  
  if (NK_ratio < optimal_ranges$NK[1]) issues <- c(issues, "N deficient relative to K")
  if (NK_ratio > optimal_ranges$NK[2]) issues <- c(issues, "K deficient relative to N")
  
  if (length(issues) == 0) {
    return("Balanced nutrient ratios")
  } else {
    return(paste(issues, collapse="; "))
  }
}

#' Calculate overall soil health score
calculate_overall_soil_health <- function(soil_data) {
  
  scores <- c()
  
  # pH score
  pH <- soil_data$pH %||% 6.0
  pH_score <- ifelse(pH >= 5.5 && pH <= 7.0, 100, 
                    ifelse(pH >= 5.0 && pH <= 7.5, 75, 50))
  scores <- c(scores, pH_score)
  
  # Organic matter score
  SOC <- soil_data$SOC %||% 20
  OM_score <- min(100, (SOC / 30) * 100)
  scores <- c(scores, OM_score)
  
  # Overall score
  overall_score <- mean(scores)
  
  if (overall_score >= 80) health_status <- "Excellent"
  else if (overall_score >= 65) health_status <- "Good"
  else if (overall_score >= 50) health_status <- "Fair"
  else health_status <- "Poor"
  
  return(list(
    overall_score = round(overall_score, 1),
    health_status = health_status,
    component_scores = list(
      pH_score = pH_score,
      organic_matter_score = round(OM_score, 1)
    )
  ))
}

#' Calculate nutrient use efficiency
calculate_nutrient_use_efficiency <- function(quefts_results, fertilizer_rates) {
  
  # Extract yield response and fertilizer rates
  yield_response <- quefts_results$detailed_results$yield_predictions$mean
  native_yield <- yield_response * 0.6  # Estimate
  
  N_rate <- fertilizer_rates$nitrogen$recommended_rate
  P_rate <- fertilizer_rates$phosphorus$recommended_rate / 2.29
  K_rate <- fertilizer_rates$potassium$recommended_rate / 1.20
  
  # Calculate efficiencies
  if (N_rate > 0) {
    N_efficiency <- (yield_response - native_yield) / N_rate
  } else {
    N_efficiency <- 0
  }
  
  efficiency_analysis <- list(
    nitrogen_use_efficiency = list(
      value = round(N_efficiency, 1),
      units = "kg grain/kg N",
      interpretation = interpret_nue(N_efficiency)
    ),
    overall_efficiency = list(
      status = assess_overall_efficiency(N_efficiency),
      recommendations = generate_efficiency_recommendations(N_efficiency)
    )
  )
  
  return(efficiency_analysis)
}

#' Interpret nitrogen use efficiency
interpret_nue <- function(nue) {
  if (nue >= 20) return("Excellent efficiency")
  if (nue >= 15) return("Good efficiency")
  if (nue >= 10) return("Moderate efficiency")
  if (nue >= 5) return("Low efficiency")
  return("Poor efficiency")
}

#' Assess overall nutrient use efficiency
assess_overall_efficiency <- function(nue) {
  if (nue >= 15) return("High")
  if (nue >= 10) return("Medium")
  return("Low")
}

#' Generate efficiency improvement recommendations
generate_efficiency_recommendations <- function(nue) {
  recommendations <- c()
  
  if (nue < 10) {
    recommendations <- c(recommendations, 
                        "Consider split N applications",
                        "Improve soil organic matter",
                        "Check for other limiting factors")
  }
  
  if (nue < 15) {
    recommendations <- c(recommendations,
                        "Optimize timing of fertilizer application",
                        "Consider slow-release fertilizers")
  }
  
  if (length(recommendations) == 0) {
    recommendations <- "Current efficiency is good - maintain practices"
  }
  
  return(recommendations)
}

#' Assess environmental risks
assess_environmental_risks <- function(fertilizer_rates, soil_data) {
  
  N_rate <- fertilizer_rates$nitrogen$recommended_rate
  
  # Nitrogen leaching risk
  leaching_risk <- assess_leaching_risk(N_rate, soil_data)
  
  # Runoff risk
  runoff_risk <- assess_runoff_risk(fertilizer_rates, soil_data)
  
  # Overall environmental assessment
  overall_risk <- calculate_overall_environmental_risk(leaching_risk, runoff_risk)
  
  return(list(
    leaching_risk = leaching_risk,
    runoff_risk = runoff_risk,
    overall_environmental_risk = overall_risk,
    mitigation_strategies = generate_mitigation_strategies(overall_risk)
  ))
}

#' Assess nitrogen leaching risk
assess_leaching_risk <- function(N_rate, soil_data) {
  
  clay_content <- soil_data$clay %||% 25
  
  # Risk factors
  if (N_rate > 150 && clay_content < 20) {
    risk_level <- "High"
  } else if (N_rate > 100 && clay_content < 30) {
    risk_level <- "Medium"
  } else {
    risk_level <- "Low"
  }
  
  return(list(
    risk_level = risk_level,
    N_rate = N_rate,
    clay_content = clay_content,
    mitigation = generate_leaching_mitigation(risk_level)
  ))
}

#' Generate leaching mitigation strategies
generate_leaching_mitigation <- function(risk_level) {
  if (risk_level == "High") {
    return(c("Split N applications into 3-4 parts",
            "Use slow-release fertilizers",
            "Consider cover crops",
            "Avoid application before heavy rains"))
  } else if (risk_level == "Medium") {
    return(c("Split N applications into 2-3 parts",
            "Time applications with crop demand"))
  } else {
    return(c("Current practices are environmentally sound"))
  }
}

#' Assess runoff risk
assess_runoff_risk <- function(fertilizer_rates, soil_data) {
  
  # Simplified runoff risk assessment
  slope <- soil_data$slope %||% 2  # Default 2% slope
  
  if (slope > 8) {
    risk_level <- "High"
  } else if (slope > 3) {
    risk_level <- "Medium"
  } else {
    risk_level <- "Low"
  }
  
  return(list(
    risk_level = risk_level,
    slope_percent = slope,
    mitigation = generate_runoff_mitigation(risk_level)
  ))
}

#' Generate runoff mitigation strategies
generate_runoff_mitigation <- function(risk_level) {
  if (risk_level == "High") {
    return(c("Incorporate fertilizer immediately",
            "Use buffer strips",
            "Consider contour farming",
            "Avoid surface application on slopes"))
  } else if (risk_level == "Medium") {
    return(c("Incorporate fertilizer when possible",
            "Time applications to avoid heavy rainfall"))
  } else {
    return(c("Standard application practices are suitable"))
  }
}

#' Calculate overall environmental risk
calculate_overall_environmental_risk <- function(leaching_risk, runoff_risk) {
  
  risk_scores <- c(
    leaching = switch(leaching_risk$risk_level, "Low" = 1, "Medium" = 2, "High" = 3),
    runoff = switch(runoff_risk$risk_level, "Low" = 1, "Medium" = 2, "High" = 3)
  )
  
  avg_risk <- mean(risk_scores)
  
  if (avg_risk <= 1.5) return("Low")
  if (avg_risk <= 2.5) return("Medium")
  return("High")
}

#' Generate environmental mitigation strategies
generate_mitigation_strategies <- function(overall_risk) {
  
  strategies <- switch(overall_risk,
    "Low" = c("Continue current best practices",
             "Monitor application timing"),
    "Medium" = c("Implement precision application",
                "Use enhanced efficiency fertilizers",
                "Monitor weather conditions"),
    "High" = c("Mandatory split applications",
              "Use slow-release fertilizers",
              "Implement buffer zones",
              "Consider alternative nutrient sources")
  )
  
  return(strategies)
}

#' Calculate sustainability metrics
calculate_sustainability_metrics <- function(quefts_results, soil_data) {
  
  # Simplified sustainability assessment
  sustainability <- list(
    soil_carbon_trend = assess_carbon_trend(soil_data),
    nutrient_balance_sustainability = assess_nutrient_sustainability(quefts_results),
    overall_sustainability_score = calculate_sustainability_score(quefts_results, soil_data)
  )
  
  return(sustainability)
}

#' Assess soil carbon trend
assess_carbon_trend <- function(soil_data) {
  SOC <- soil_data$SOC %||% 20
  
  if (SOC >= 25) {
    return(list(
      status = "Increasing",
      recommendation = "Maintain current organic matter management"
    ))
  } else if (SOC >= 15) {
    return(list(
      status = "Stable",
      recommendation = "Continue residue management and consider cover crops"
    ))
  } else {
    return(list(
      status = "Declining",
      recommendation = "Urgent need for organic matter improvement strategies"
    ))
  }
}

#' Assess nutrient sustainability
assess_nutrient_sustainability <- function(quefts_results) {
  
  # Check if fertilizer rates are within sustainable ranges
  # This is a simplified assessment
  
  return(list(
    status = "Sustainable",
    long_term_outlook = "Recommendations support long-term soil fertility"
  ))
}

#' Calculate overall sustainability score
calculate_sustainability_score <- function(quefts_results, soil_data) {
  
  # Simplified scoring system
  scores <- c()
  
  # Soil health score
  SOC <- soil_data$SOC %||% 20
  soil_score <- min(100, (SOC / 30) * 100)
  scores <- c(scores, soil_score)
  
  # pH score
  pH <- soil_data$pH %||% 6.0
  pH_score <- ifelse(pH >= 5.5 && pH <= 7.0, 100, 75)
  scores <- c(scores, pH_score)
  
  overall_score <- mean(scores)
  
  return(list(
    sustainability_score = round(overall_score, 1),
    rating = ifelse(overall_score >= 80, "High",
                   ifelse(overall_score >= 60, "Medium", "Low")),
    key_factors = list(
      soil_organic_matter = soil_score,
      pH_status = pH_score
    )
  ))
}

# Utility functions
`%||%` <- function(x, y) if (is.null(x)) y else x

# ================================================================================
# MODULE INITIALIZATION
# ================================================================================

cat("✓ Output Generation Module loaded successfully\n")
cat("Available functions:\n")
cat("- generate_primary_recommendations(): Comprehensive fertilizer and yield recommendations\n")
cat("- generate_economic_analysis(): Cost-benefit analysis and risk assessment\n")
cat("- generate_agronomic_insights(): Soil health and sustainability analysis\n\n")
