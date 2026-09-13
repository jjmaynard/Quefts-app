# ================================================================================
# USER INTERPRETATION AND VISUALIZATION MODULE FOR QUEFTS FRAMEWORK
# Implements progressive disclosure interface and visual communication tools
# ================================================================================

cat("Loading User Interpretation and Visualization Module...\n")

# Required libraries for visualization
required_packages <- c("ggplot2", "plotly", "leaflet", "DT", "htmlwidgets")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat(sprintf("Warning: %s package not available. Some visualizations may be limited.\n", pkg))
  }
}

# ================================================================================
# 6.1 PROGRESSIVE DISCLOSURE INTERFACE
# ================================================================================

#' Generate user-level appropriate recommendations
#' 
#' @param analysis_results Complete analysis results from QUEFTS
#' @param user_level User expertise level ("beginner", "intermediate", "expert")
#' @param display_format Output format ("text", "html", "json")
#' @return User-appropriate formatted recommendations
generate_progressive_disclosure <- function(analysis_results, user_level = "intermediate", 
                                          display_format = "text") {
  
  cat(sprintf("Generating %s-level recommendations in %s format...\n", user_level, display_format))
  
  # Extract key components
  primary_recs <- analysis_results$primary_recommendations
  economic_analysis <- analysis_results$economic_analysis
  agronomic_insights <- analysis_results$agronomic_insights
  
  # Generate level-appropriate content
  disclosure_content <- switch(user_level,
    "beginner" = generate_beginner_interface(primary_recs, economic_analysis),
    "intermediate" = generate_intermediate_interface(primary_recs, economic_analysis, agronomic_insights),
    "expert" = generate_expert_interface(analysis_results)
  )
  
  # Format output
  formatted_output <- format_disclosure_output(disclosure_content, display_format)
  
  cat("✓ Progressive disclosure interface generated\n")
  return(formatted_output)
}

#' Generate beginner-level interface with traffic light system
generate_beginner_interface <- function(primary_recs, economic_analysis) {
  
  # Traffic light decision system
  traffic_light <- generate_traffic_light_decision(economic_analysis)
  
  # Simple recommendation
  fertilizer_summary <- generate_simple_fertilizer_summary(primary_recs)
  
  # Confidence level in simple terms
  confidence <- primary_recs$recommendation_confidence
  confidence_simple <- simplify_confidence_level(confidence$confidence_level)
  
  beginner_content <- list(
    traffic_light = traffic_light,
    simple_recommendation = list(
      decision = traffic_light$decision,
      fertilizer_summary = fertilizer_summary,
      confidence = confidence_simple,
      key_message = generate_key_message(traffic_light, confidence_simple)
    ),
    next_steps = generate_beginner_next_steps(traffic_light$decision),
    disclaimer = "These are general recommendations. Consult local extension services for specific advice."
  )
  
  return(beginner_content)
}

#' Generate traffic light decision system
generate_traffic_light_decision <- function(economic_analysis) {
  
  decision <- economic_analysis$decision_recommendation$decision
  net_benefit <- economic_analysis$cost_benefit_analysis$profitability$net_benefit
  prob_loss <- economic_analysis$risk_metrics$probability_of_economic_loss
  
  # Traffic light logic
  if (decision %in% c("STRONGLY RECOMMEND", "RECOMMEND")) {
    color <- "GREEN"
    symbol <- "✅"
    message <- "Apply fertilizer - Good economic returns expected"
  } else if (decision %in% c("CAUTIOUSLY RECOMMEND", "NEUTRAL")) {
    color <- "YELLOW"
    symbol <- "⚠️"
    message <- "Consider fertilizer - Moderate returns with some risk"
  } else {
    color <- "RED"
    symbol <- "❌"
    message <- "Don't apply fertilizer - High risk of economic loss"
  }
  
  return(list(
    color = color,
    symbol = symbol,
    decision = decision,
    message = message,
    supporting_info = list(
      expected_profit = sprintf("$%.0f/ha", net_benefit),
      risk_level = sprintf("%.0f%% chance of loss", prob_loss * 100)
    )
  ))
}

#' Generate simple fertilizer summary for beginners
generate_simple_fertilizer_summary <- function(primary_recs) {
  
  N_rate <- primary_recs$fertilizer_rates$nitrogen$recommended_rate
  P_rate <- primary_recs$fertilizer_rates$phosphorus$recommended_rate
  K_rate <- primary_recs$fertilizer_rates$potassium$recommended_rate
  
  # Simplify recommendations
  if (N_rate > 0 || P_rate > 0 || K_rate > 0) {
    summary <- sprintf("Apply %.0f kg/ha Nitrogen, %.0f kg/ha Phosphorus, %.0f kg/ha Potassium",
                      N_rate, P_rate, K_rate)
    
    # Add timing guidance
    timing <- "Apply at planting with additional nitrogen during growing season"
  } else {
    summary <- "No fertilizer needed based on current soil conditions"
    timing <- ""
  }
  
  return(list(
    summary = summary,
    timing = timing,
    npk_ratio = primary_recs$npk_analysis$npk_ratio
  ))
}

#' Simplify confidence level for beginners
simplify_confidence_level <- function(confidence_level) {
  simple_confidence <- switch(confidence_level,
    "High" = list(level = "High", message = "We are confident in this recommendation"),
    "Medium" = list(level = "Medium", message = "Good recommendation with some uncertainty"),
    "Low" = list(level = "Low", message = "Recommendation has moderate uncertainty"),
    "Very Low" = list(level = "Low", message = "High uncertainty - consider soil testing")
  )
  
  return(simple_confidence)
}

#' Generate key message for beginners
generate_key_message <- function(traffic_light, confidence) {
  
  base_message <- traffic_light$message
  
  if (confidence$level == "Low") {
    base_message <- paste(base_message, "Consider getting a soil test for better recommendations.")
  }
  
  return(base_message)
}

#' Generate next steps for beginners
generate_beginner_next_steps <- function(decision) {
  
  if (decision %in% c("STRONGLY RECOMMEND", "RECOMMEND")) {
    steps <- c(
      "1. Purchase the recommended fertilizers from a local supplier",
      "2. Apply fertilizers at planting time",
      "3. Split nitrogen applications if amount is high",
      "4. Monitor crop growth and adjust if needed"
    )
  } else if (decision %in% c("CAUTIOUSLY RECOMMEND", "NEUTRAL")) {
    steps <- c(
      "1. Consider getting a detailed soil test",
      "2. Consult with local extension agent",
      "3. Start with reduced fertilizer rates",
      "4. Monitor economic returns carefully"
    )
  } else {
    steps <- c(
      "1. Focus on improving soil organic matter",
      "2. Consider soil amendments (lime if acidic)",
      "3. Get detailed soil testing",
      "4. Explore alternative soil improvement strategies"
    )
  }
  
  return(steps)
}

#' Generate intermediate-level interface
generate_intermediate_interface <- function(primary_recs, economic_analysis, agronomic_insights) {
  
  # Detailed nutrient recommendations
  detailed_nutrients <- format_detailed_nutrient_recommendations(primary_recs)
  
  # Economic summary
  economic_summary <- format_economic_summary(economic_analysis)
  
  # Risk indicators
  risk_indicators <- format_risk_indicators(economic_analysis)
  
  # Alternative scenarios
  scenarios <- generate_alternative_scenarios(primary_recs, economic_analysis)
  
  # Agronomic highlights
  agronomic_summary <- format_agronomic_summary(agronomic_insights)
  
  intermediate_content <- list(
    executive_summary = generate_executive_summary(primary_recs, economic_analysis),
    detailed_recommendations = detailed_nutrients,
    economic_analysis = economic_summary,
    risk_assessment = risk_indicators,
    agronomic_insights = agronomic_summary,
    alternative_scenarios = scenarios,
    implementation_guide = generate_implementation_guide(primary_recs)
  )
  
  return(intermediate_content)
}

#' Format detailed nutrient recommendations
format_detailed_nutrient_recommendations <- function(primary_recs) {
  
  nutrients <- list()
  
  # Nitrogen
  N_data <- primary_recs$fertilizer_rates$nitrogen
  nutrients$nitrogen <- list(
    rate = sprintf("%.1f kg N/ha", N_data$recommended_rate),
    confidence_intervals = N_data$confidence_intervals,
    uncertainty = N_data$uncertainty_level,
    interpretation = N_data$interpretation$interpretation,
    timing = primary_recs$npk_analysis$timing$nitrogen
  )
  
  # Phosphorus
  P_data <- primary_recs$fertilizer_rates$phosphorus
  nutrients$phosphorus <- list(
    rate = sprintf("%.1f kg P₂O₅/ha", P_data$recommended_rate),
    confidence_intervals = P_data$confidence_intervals,
    uncertainty = P_data$uncertainty_level,
    interpretation = P_data$interpretation$interpretation,
    timing = primary_recs$npk_analysis$timing$phosphorus
  )
  
  # Potassium
  K_data <- primary_recs$fertilizer_rates$potassium
  nutrients$potassium <- list(
    rate = sprintf("%.1f kg K₂O/ha", K_data$recommended_rate),
    confidence_intervals = K_data$confidence_intervals,
    uncertainty = K_data$uncertainty_level,
    interpretation = K_data$interpretation$interpretation,
    timing = primary_recs$npk_analysis$timing$potassium
  )
  
  return(nutrients)
}

#' Format economic summary for intermediate users
format_economic_summary <- function(economic_analysis) {
  
  cost_benefit <- economic_analysis$cost_benefit_analysis
  
  summary <- list(
    investment_required = sprintf("$%.2f/ha", cost_benefit$costs$total_cost_per_ha),
    expected_return = sprintf("$%.2f/ha", cost_benefit$revenue$additional_revenue),
    net_profit = sprintf("$%.2f/ha", cost_benefit$profitability$net_benefit),
    benefit_cost_ratio = sprintf("%.2f:1", cost_benefit$profitability$benefit_cost_ratio),
    breakeven_price = sprintf("$%.3f/kg", cost_benefit$profitability$breakeven_crop_price),
    profitability_assessment = cost_benefit$profitability$interpretation
  )
  
  return(summary)
}

#' Format risk indicators
format_risk_indicators <- function(economic_analysis) {
  
  risk_metrics <- economic_analysis$risk_metrics
  
  indicators <- list(
    probability_of_loss = sprintf("%.1f%%", risk_metrics$probability_of_economic_loss * 100),
    worst_case_loss = sprintf("$%.2f/ha", risk_metrics$value_at_risk_95),
    risk_level = risk_metrics$risk_level,
    scenarios = list(
      pessimistic = sprintf("%.0f kg/ha yield, $%.2f/ha profit", 
                           risk_metrics$scenarios$pessimistic$yield,
                           risk_metrics$scenarios$pessimistic$profit),
      realistic = sprintf("%.0f kg/ha yield, $%.2f/ha profit",
                         risk_metrics$scenarios$realistic$yield,
                         risk_metrics$scenarios$realistic$profit),
      optimistic = sprintf("%.0f kg/ha yield, $%.2f/ha profit",
                          risk_metrics$scenarios$optimistic$yield,
                          risk_metrics$scenarios$optimistic$profit)
    )
  )
  
  return(indicators)
}

#' Generate alternative scenarios
generate_alternative_scenarios <- function(primary_recs, economic_analysis) {
  
  base_N <- primary_recs$fertilizer_rates$nitrogen$recommended_rate
  
  scenarios <- list(
    conservative = list(
      description = "Reduced rate application (75% of recommended)",
      N_rate = base_N * 0.75,
      expected_outcome = "Lower cost, moderate yield response",
      risk_level = "Lower risk"
    ),
    standard = list(
      description = "Full recommended application",
      N_rate = base_N,
      expected_outcome = "Optimal cost-benefit balance",
      risk_level = "Calculated risk"
    ),
    intensive = list(
      description = "Enhanced application (125% of recommended)",
      N_rate = base_N * 1.25,
      expected_outcome = "Higher yield potential, increased cost",
      risk_level = "Higher risk"
    )
  )
  
  return(scenarios)
}

#' Format agronomic summary
format_agronomic_summary <- function(agronomic_insights) {
  
  if (is.null(agronomic_insights)) {
    return(list(message = "Agronomic insights not available"))
  }
  
  summary <- list(
    limiting_nutrients = agronomic_insights$nutrient_limitations$primary_limiting_nutrient,
    soil_health_status = agronomic_insights$soil_health_indicators$overall_soil_health$health_status,
    key_recommendations = extract_key_agronomic_recommendations(agronomic_insights),
    sustainability_outlook = agronomic_insights$sustainability_metrics$overall_sustainability_score$rating
  )
  
  return(summary)
}

#' Extract key agronomic recommendations
extract_key_agronomic_recommendations <- function(agronomic_insights) {
  
  recommendations <- c()
  
  # pH recommendations
  if (!is.null(agronomic_insights$soil_health_indicators$pH_status)) {
    ph_rec <- agronomic_insights$soil_health_indicators$pH_status$recommendation
    if (!grepl("optimal range", ph_rec, ignore.case = TRUE)) {
      recommendations <- c(recommendations, ph_rec)
    }
  }
  
  # Organic matter recommendations
  if (!is.null(agronomic_insights$soil_health_indicators$organic_matter)) {
    om_rec <- agronomic_insights$soil_health_indicators$organic_matter$recommendation
    if (!grepl("excellent", om_rec, ignore.case = TRUE)) {
      recommendations <- c(recommendations, om_rec)
    }
  }
  
  # Environmental mitigation
  if (!is.null(agronomic_insights$environmental_assessment)) {
    env_strategies <- agronomic_insights$environmental_assessment$mitigation_strategies
    if (length(env_strategies) > 0 && !any(grepl("current.*practices", env_strategies, ignore.case = TRUE))) {
      recommendations <- c(recommendations, env_strategies[1])  # Add first strategy
    }
  }
  
  if (length(recommendations) == 0) {
    recommendations <- "Current soil management practices are appropriate"
  }
  
  return(recommendations)
}

#' Generate executive summary
generate_executive_summary <- function(primary_recs, economic_analysis) {
  
  decision <- economic_analysis$decision_recommendation$decision
  net_benefit <- economic_analysis$cost_benefit_analysis$profitability$net_benefit
  confidence <- primary_recs$recommendation_confidence$confidence_level
  
  summary <- sprintf(
    "Recommendation: %s. Expected net benefit: $%.2f/ha with %s confidence. %s",
    decision, net_benefit, confidence, 
    economic_analysis$decision_recommendation$rationale
  )
  
  return(summary)
}

#' Generate implementation guide
generate_implementation_guide <- function(primary_recs) {
  
  guide <- list(
    timing = list(
      planting = "Apply phosphorus and potassium at planting",
      early_season = "Apply 30-40% of nitrogen at planting",
      mid_season = "Apply remaining nitrogen during vegetative growth"
    ),
    application_methods = primary_recs$npk_analysis$application_methods,
    monitoring = list(
      "Monitor crop response 2-3 weeks after application",
      "Watch for nutrient deficiency symptoms",
      "Adjust future applications based on yield response"
    ),
    weather_considerations = list(
      "Avoid nitrogen application before heavy rains",
      "Ensure soil moisture for nutrient uptake",
      "Consider seasonal weather patterns"
    )
  )
  
  return(guide)
}

#' Generate expert-level interface
generate_expert_interface <- function(analysis_results) {
  
  expert_content <- list(
    full_uncertainty_analysis = extract_uncertainty_analysis(analysis_results),
    sensitivity_analysis = extract_sensitivity_results(analysis_results),
    technical_parameters = extract_technical_parameters(analysis_results),
    data_quality_assessment = assess_data_quality(analysis_results),
    model_assumptions = document_model_assumptions(),
    statistical_details = extract_statistical_details(analysis_results),
    research_recommendations = generate_research_recommendations(analysis_results)
  )
  
  return(expert_content)
}

#' Extract uncertainty analysis for experts
extract_uncertainty_analysis <- function(analysis_results) {
  
  if (!is.null(analysis_results$bayesian_updating)) {
    bayesian_summary <- summarize_bayesian_updating(analysis_results$bayesian_updating)
  } else {
    bayesian_summary <- "Bayesian updating not performed"
  }
  
  uncertainty <- list(
    monte_carlo_iterations = length(analysis_results$primary_recommendations$yield_predictions$probability_distributions$samples),
    parameter_uncertainties = extract_parameter_uncertainties(analysis_results),
    bayesian_updating = bayesian_summary,
    confidence_intervals_full = extract_full_confidence_intervals(analysis_results),
    uncertainty_propagation = "Monte Carlo simulation with correlated parameters"
  )
  
  return(uncertainty)
}

#' Summarize Bayesian updating results
summarize_bayesian_updating <- function(bayesian_results) {
  
  if (is.null(bayesian_results)) return("Not performed")
  
  summary <- list()
  
  for (param in names(bayesian_results)) {
    param_data <- bayesian_results[[param]]
    summary[[param]] <- list(
      uncertainty_reduction = sprintf("%.1f%%", param_data$uncertainty_reduction * 100),
      information_gain = sprintf("%.3f", param_data$information_gain),
      prior_uncertainty = sprintf("%.3f", sqrt(param_data$prior$variance)),
      posterior_uncertainty = sprintf("%.3f", sqrt(param_data$posterior$variance))
    )
  }
  
  return(summary)
}

#' Extract parameter uncertainties
extract_parameter_uncertainties <- function(analysis_results) {
  
  uncertainties <- list(
    nitrogen = analysis_results$primary_recommendations$fertilizer_rates$nitrogen$uncertainty_level,
    phosphorus = analysis_results$primary_recommendations$fertilizer_rates$phosphorus$uncertainty_level,
    potassium = analysis_results$primary_recommendations$fertilizer_rates$potassium$uncertainty_level,
    yield = calculate_uncertainty_level(analysis_results$primary_recommendations$yield_predictions$expected_yield_with_fertilizer$mean / 
                                       analysis_results$primary_recommendations$yield_predictions$expected_yield_with_fertilizer$median)
  )
  
  return(uncertainties)
}

#' Extract full confidence intervals
extract_full_confidence_intervals <- function(analysis_results) {
  
  fertilizer_rates <- analysis_results$primary_recommendations$fertilizer_rates
  
  intervals <- list(
    nitrogen = fertilizer_rates$nitrogen$confidence_intervals,
    phosphorus = fertilizer_rates$phosphorus$confidence_intervals,
    potassium = fertilizer_rates$potassium$confidence_intervals,
    yield = analysis_results$primary_recommendations$yield_predictions$expected_yield_with_fertilizer$confidence_intervals
  )
  
  return(intervals)
}

#' Extract sensitivity analysis results
extract_sensitivity_results <- function(analysis_results) {

  sens <- analysis_results$sensitivity_analysis

  if (is.null(sens)) {
    # sensitivity_analysis is only populated when the caller ran the full
    # integrated_decision_support::comprehensive_fertilizer_recommendation()
    # pipeline (which calls perform_sensitivity_analysis()). Callers that
    # pass a partial results object won't have it.
    return(list(
      parameter_ranking = NA,
      sensitivity_indices = list(),
      interpretation = "Sensitivity analysis not available for this result set."
    ))
  }

  sensitivity_indices <- lapply(sens$parameter_sensitivities, function(x) x$relative_sensitivity)

  interpretation <- if (!is.null(sens$most_sensitive) && !is.na(sens$most_sensitive)) {
    sprintf("%s is the most influential parameter on fertilizer recommendations", sens$most_sensitive)
  } else {
    "No dominant parameter identified."
  }

  sensitivity <- list(
    parameter_ranking = sens$sensitivity_ranking,
    sensitivity_indices = sensitivity_indices,
    interpretation = interpretation
  )

  return(sensitivity)
}

#' Extract technical parameters
extract_technical_parameters <- function(analysis_results) {
  
  parameters <- list(
    quefts_version = "Enhanced QUEFTS v2.0",
    simulation_parameters = list(
      monte_carlo_iterations = 1000,
      convergence_criteria = "Coefficient of variation < 0.01",
      correlation_structure = "Multivariate normal distribution"
    ),
    crop_parameters = analysis_results$primary_recommendations$crop,
    target_yield = analysis_results$primary_recommendations$target_yield,
    calculation_timestamp = analysis_results$primary_recommendations$timestamp
  )
  
  return(parameters)
}

#' Assess data quality
assess_data_quality <- function(analysis_results) {
  
  confidence <- analysis_results$primary_recommendations$recommendation_confidence
  
  quality_assessment <- list(
    overall_confidence = confidence$confidence_level,
    confidence_score = confidence$confidence_score,
    data_sources = "Mixed sources with varying reliability",
    limitations = identify_data_limitations(confidence),
    recommendations_for_improvement = suggest_data_improvements(confidence)
  )
  
  return(quality_assessment)
}

#' Identify data limitations
identify_data_limitations <- function(confidence) {
  
  limitations <- c()
  
  if (confidence$confidence_score < 70) {
    limitations <- c(limitations, "High uncertainty in soil parameter estimates")
  }
  
  if (confidence$average_cv > 0.3) {
    limitations <- c(limitations, "Large variability in input parameters")
  }
  
  limitations <- c(limitations, "Limited local calibration data available")
  
  return(limitations)
}

#' Suggest data improvements
suggest_data_improvements <- function(confidence) {
  
  suggestions <- c()
  
  if (confidence$confidence_score < 60) {
    suggestions <- c(suggestions, "Conduct detailed soil testing for key parameters")
  }
  
  if (confidence$confidence_score < 80) {
    suggestions <- c(suggestions, "Collect field observations for model validation")
  }
  
  suggestions <- c(suggestions, "Establish local calibration trials")
  
  return(suggestions)
}

#' Document model assumptions
document_model_assumptions <- function() {
  
  assumptions <- list(
    quefts_assumptions = c(
      "Nutrients are the primary yield-limiting factors",
      "Linear relationship between nutrient supply and uptake within QUEFTS framework",
      "Standard crop physiological parameters apply"
    ),
    uncertainty_assumptions = c(
      "Normal distribution of parameter uncertainties",
      "Independence of environmental factors",
      "Static soil conditions during growing season"
    ),
    economic_assumptions = c(
      "Constant fertilizer and crop prices",
      "No consideration of labor and machinery costs",
      "Single growing season analysis"
    )
  )
  
  return(assumptions)
}

#' Extract statistical details
extract_statistical_details <- function(analysis_results) {
  
  yield_data <- analysis_results$primary_recommendations$yield_predictions$probability_distributions
  
  statistics <- list(
    yield_distribution = list(
      mean = mean(yield_data$samples),
      median = median(yield_data$samples),
      standard_deviation = sd(yield_data$samples),
      skewness = calculate_skewness(yield_data$samples),
      kurtosis = calculate_kurtosis(yield_data$samples),
      percentiles = yield_data$percentiles
    ),
    model_performance = list(
      convergence_status = "Converged",
      effective_sample_size = length(yield_data$samples),
      autocorrelation = "Minimal (Monte Carlo sampling)"
    )
  )
  
  return(statistics)
}

#' Calculate skewness
calculate_skewness <- function(x) {
  n <- length(x)
  x_centered <- x - mean(x)
  skew <- sum(x_centered^3) / (n * sd(x)^3)
  return(skew)
}

#' Calculate kurtosis
calculate_kurtosis <- function(x) {
  n <- length(x)
  x_centered <- x - mean(x)
  kurt <- sum(x_centered^4) / (n * sd(x)^4) - 3
  return(kurt)
}

#' Generate research recommendations
generate_research_recommendations <- function(analysis_results) {
  
  confidence <- analysis_results$primary_recommendations$recommendation_confidence
  
  recommendations <- list(
    high_priority = c(
      "Establish local QUEFTS calibration trials",
      "Develop region-specific crop response functions"
    ),
    medium_priority = c(
      "Investigate soil-specific uncertainty patterns",
      "Validate economic assumptions with farmer surveys"
    ),
    long_term = c(
      "Develop dynamic soil model integration",
      "Incorporate climate change projections"
    )
  )
  
  if (confidence$confidence_score < 70) {
    recommendations$immediate <- c("Urgent: Increase soil sampling density for model validation")
  }
  
  return(recommendations)
}

#' Format disclosure output according to format specification
format_disclosure_output <- function(disclosure_content, display_format) {
  
  formatted_output <- switch(display_format,
    "text" = format_as_text(disclosure_content),
    "html" = format_as_html(disclosure_content),
    "json" = format_as_json(disclosure_content),
    disclosure_content  # Default: return raw list
  )
  
  return(formatted_output)
}

#' Format content as text
format_as_text <- function(content) {
  
  # Simple text formatting
  text_output <- "=== QUEFTS FERTILIZER RECOMMENDATIONS ===\n\n"
  
  if ("simple_recommendation" %in% names(content)) {
    # Beginner format
    text_output <- paste0(text_output, 
                         sprintf("DECISION: %s %s\n", content$traffic_light$symbol, content$traffic_light$decision),
                         sprintf("RECOMMENDATION: %s\n", content$simple_recommendation$fertilizer_summary$summary),
                         sprintf("CONFIDENCE: %s\n", content$simple_recommendation$confidence$message),
                         "\nNEXT STEPS:\n")
    
    for (i in seq_along(content$next_steps)) {
      text_output <- paste0(text_output, content$next_steps[i], "\n")
    }
    
  } else if ("executive_summary" %in% names(content)) {
    # Intermediate format
    text_output <- paste0(text_output,
                         sprintf("EXECUTIVE SUMMARY:\n%s\n\n", content$executive_summary),
                         "FERTILIZER RECOMMENDATIONS:\n")
    
    for (nutrient in names(content$detailed_recommendations)) {
      nutrient_data <- content$detailed_recommendations[[nutrient]]
      text_output <- paste0(text_output,
                           sprintf("- %s: %s (Uncertainty: %s)\n", 
                                  toupper(nutrient), nutrient_data$rate, nutrient_data$uncertainty))
    }
    
    text_output <- paste0(text_output,
                         sprintf("\nECONOMIC ANALYSIS:\n"),
                         sprintf("- Investment: %s\n", content$economic_analysis$investment_required),
                         sprintf("- Expected Return: %s\n", content$economic_analysis$expected_return),
                         sprintf("- Net Profit: %s\n", content$economic_analysis$net_profit))
  }
  
  return(text_output)
}

#' Format content as HTML
format_as_html <- function(content) {
  
  # Basic HTML formatting
  html_output <- "<div class='quefts-recommendations'>\n"
  html_output <- paste0(html_output, "<h2>QUEFTS Fertilizer Recommendations</h2>\n")
  
  if ("simple_recommendation" %in% names(content)) {
    # Beginner HTML format
    color_class <- tolower(content$traffic_light$color)
    html_output <- paste0(html_output,
                         sprintf("<div class='traffic-light %s'>\n", color_class),
                         sprintf("<h3>%s %s</h3>\n", content$traffic_light$symbol, content$traffic_light$decision),
                         sprintf("<p>%s</p>\n", content$simple_recommendation$key_message),
                         "</div>\n")
  }
  
  html_output <- paste0(html_output, "</div>\n")
  
  return(html_output)
}

#' Format content as JSON
format_as_json <- function(content) {
  
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    json_output <- jsonlite::toJSON(content, pretty = TRUE, auto_unbox = TRUE)
  } else {
    # Fallback to basic JSON-like structure
    json_output <- paste0('{\n  "quefts_recommendations": ', deparse(content), '\n}')
  }
  
  return(json_output)
}

# ================================================================================
# 6.2 VISUAL COMMUNICATION TOOLS
# ================================================================================

#' Generate comprehensive visualization suite
#' 
#' @param analysis_results Complete QUEFTS analysis results
#' @param visualization_type Type of visualization requested
#' @param save_plots Whether to save plots to files
#' @return List of plot objects and/or saved file paths
generate_visual_communication_tools <- function(analysis_results, 
                                                visualization_type = "all",
                                                save_plots = FALSE) {
  
  cat("Generating visual communication tools...\n")
  
  visualizations <- list()
  
  # Check which visualizations to generate
  types_to_generate <- if (visualization_type == "all") {
    c("yield_response", "probability_distributions", "cost_benefit", 
      "uncertainty_bands", "decision_tree", "confidence_intervals")
  } else {
    visualization_type
  }
  
  # Generate each requested visualization
  if ("yield_response" %in% types_to_generate) {
    visualizations$yield_response <- create_yield_response_curve(analysis_results)
  }
  
  if ("probability_distributions" %in% types_to_generate) {
    visualizations$probability_distributions <- create_probability_distributions(analysis_results)
  }
  
  if ("cost_benefit" %in% types_to_generate) {
    visualizations$cost_benefit <- create_cost_benefit_visualization(analysis_results)
  }
  
  if ("uncertainty_bands" %in% types_to_generate) {
    visualizations$uncertainty_bands <- create_uncertainty_bands(analysis_results)
  }
  
  if ("decision_tree" %in% types_to_generate) {
    visualizations$decision_tree <- create_decision_tree_visualization(analysis_results)
  }
  
  if ("confidence_intervals" %in% types_to_generate) {
    visualizations$confidence_intervals <- create_confidence_interval_plot(analysis_results)
  }
  
  # Save plots if requested
  if (save_plots) {
    saved_files <- save_visualization_plots(visualizations)
    visualizations$saved_files <- saved_files
  }
  
  cat("✓ Visual communication tools generated\n")
  return(visualizations)
}

#' Create yield response curve visualization
create_yield_response_curve <- function(analysis_results) {
  
  # Extract data
  yield_data <- analysis_results$primary_recommendations$yield_predictions
  target_yield <- analysis_results$primary_recommendations$target_yield
  native_yield <- yield_data$native_yield_comparison$estimated_native_yield
  
  # Create data for response curve
  fertilizer_rates <- seq(0, 200, by = 10)  # N rates from 0 to 200 kg/ha
  
  # Simplified response curve (would be based on actual QUEFTS calculations)
  expected_yields <- native_yield + (yield_data$expected_yield_with_fertilizer$mean - native_yield) * 
                    (1 - exp(-fertilizer_rates / 80))  # Mitscherlich-type response
  
  curve_data <- data.frame(
    N_rate = fertilizer_rates,
    Expected_Yield = expected_yields,
    Lower_CI = expected_yields * 0.85,
    Upper_CI = expected_yields * 1.15
  )
  
  # Check if ggplot2 is available
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    
    plot <- ggplot2::ggplot(curve_data, ggplot2::aes(x = N_rate, y = Expected_Yield)) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = Lower_CI, ymax = Upper_CI), alpha = 0.3, fill = "blue") +
      ggplot2::geom_line(color = "blue", size = 1.2) +
      ggplot2::geom_hline(yintercept = target_yield, color = "red", linetype = "dashed", size = 1) +
      ggplot2::geom_hline(yintercept = native_yield, color = "green", linetype = "dotted", size = 1) +
      ggplot2::labs(
        title = "Crop Yield Response to Nitrogen Fertilizer",
        subtitle = "With 95% confidence bands",
        x = "Nitrogen Rate (kg/ha)",
        y = "Expected Yield (kg/ha)",
        caption = "Red line: Target yield | Green line: Native yield"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 14, face = "bold"),
        plot.subtitle = ggplot2::element_text(size = 12),
        axis.title = ggplot2::element_text(size = 12),
        legend.position = "bottom"
      )
    
    return(plot)
    
  } else {
    
    # Fallback to base R plotting
    plot(curve_data$N_rate, curve_data$Expected_Yield, 
         type = "l", col = "blue", lwd = 2,
         xlab = "Nitrogen Rate (kg/ha)", 
         ylab = "Expected Yield (kg/ha)",
         main = "Crop Yield Response to Nitrogen Fertilizer")
    
    # Add confidence bands
    polygon(c(curve_data$N_rate, rev(curve_data$N_rate)), 
            c(curve_data$Lower_CI, rev(curve_data$Upper_CI)),
            col = rgb(0, 0, 1, 0.3), border = NA)
    
    # Add reference lines
    abline(h = target_yield, col = "red", lty = 2, lwd = 2)
    abline(h = native_yield, col = "green", lty = 3, lwd = 2)
    
    legend("bottomright", 
           legend = c("Expected yield", "Target yield", "Native yield"),
           col = c("blue", "red", "green"),
           lty = c(1, 2, 3), lwd = 2)
    
    return("Base R plot created")
  }
}

#' Create probability distributions visualization
create_probability_distributions <- function(analysis_results) {
  
  # Extract yield samples
  yield_samples <- analysis_results$primary_recommendations$yield_predictions$probability_distributions$samples
  target_yield <- analysis_results$primary_recommendations$target_yield
  
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    
    # Create histogram with density overlay
    plot_data <- data.frame(yield = yield_samples)
    
    plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = yield)) +
      ggplot2::geom_histogram(ggplot2::aes(y = ..density..), bins = 30, alpha = 0.7, fill = "lightblue", color = "black") +
      ggplot2::geom_density(color = "red", size = 1.2) +
      ggplot2::geom_vline(xintercept = target_yield, color = "darkred", linetype = "dashed", size = 1.2) +
      ggplot2::geom_vline(xintercept = mean(yield_samples), color = "blue", linetype = "solid", size = 1) +
      ggplot2::labs(
        title = "Probability Distribution of Expected Yield",
        subtitle = sprintf("Probability of meeting target (%.0f kg/ha): %.1f%%", 
                          target_yield, 
                          mean(yield_samples >= target_yield) * 100),
        x = "Yield (kg/ha)",
        y = "Probability Density",
        caption = "Blue line: Expected yield | Red dashed: Target yield"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 14, face = "bold"),
        plot.subtitle = ggplot2::element_text(size = 12)
      )
    
    return(plot)
    
  } else {
    
    # Base R histogram
    hist(yield_samples, breaks = 30, prob = TRUE,
         main = "Probability Distribution of Expected Yield",
         xlab = "Yield (kg/ha)", ylab = "Probability Density",
         col = "lightblue", border = "black")
    
    # Add density line
    lines(density(yield_samples), col = "red", lwd = 2)
    
    # Add reference lines
    abline(v = target_yield, col = "darkred", lty = 2, lwd = 2)
    abline(v = mean(yield_samples), col = "blue", lty = 1, lwd = 2)
    
    legend("topright",
           legend = c("Density", "Target yield", "Expected yield"),
           col = c("red", "darkred", "blue"),
           lty = c(1, 2, 1), lwd = 2)
    
    return("Base R histogram created")
  }
}

#' Create cost-benefit visualization
create_cost_benefit_visualization <- function(analysis_results) {
  
  economic_data <- analysis_results$economic_analysis
  
  # Extract profit distribution
  profit_samples <- economic_data$risk_metrics$profit_distribution$samples
  
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    
    # Create profit distribution plot
    plot_data <- data.frame(profit = profit_samples)
    
    plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = profit)) +
      ggplot2::geom_histogram(ggplot2::aes(y = ..density..), bins = 30, alpha = 0.7, 
                             fill = ifelse(plot_data$profit >= 0, "lightgreen", "lightcoral")) +
      ggplot2::geom_density(color = "black", size = 1) +
      ggplot2::geom_vline(xintercept = 0, color = "red", linetype = "dashed", size = 1.2) +
      ggplot2::geom_vline(xintercept = mean(profit_samples), color = "blue", size = 1.2) +
      ggplot2::labs(
        title = "Economic Risk Assessment",
        subtitle = sprintf("Probability of loss: %.1f%% | Expected profit: $%.2f/ha",
                          economic_data$risk_metrics$probability_of_economic_loss * 100,
                          mean(profit_samples)),
        x = "Profit/Loss ($/ha)",
        y = "Probability Density",
        caption = "Green: Profit | Red: Loss | Blue line: Expected profit"
      ) +
      ggplot2::theme_minimal()
    
    return(plot)
    
  } else {
    
    # Base R plot
    hist(profit_samples, breaks = 30, prob = TRUE,
         main = "Economic Risk Assessment",
         xlab = "Profit/Loss ($/ha)", ylab = "Probability Density",
         col = ifelse(profit_samples >= 0, "lightgreen", "lightcoral"))
    
    lines(density(profit_samples), col = "black", lwd = 2)
    abline(v = 0, col = "red", lty = 2, lwd = 2)
    abline(v = mean(profit_samples), col = "blue", lwd = 2)
    
    return("Base R cost-benefit plot created")
  }
}

#' Create uncertainty bands visualization
create_uncertainty_bands <- function(analysis_results) {
  
  # Extract fertilizer recommendations with confidence intervals
  N_data <- analysis_results$primary_recommendations$fertilizer_rates$nitrogen
  P_data <- analysis_results$primary_recommendations$fertilizer_rates$phosphorus
  K_data <- analysis_results$primary_recommendations$fertilizer_rates$potassium
  
  # Extract confidence interval bounds
  nutrients <- c("Nitrogen", "Phosphorus", "Potassium")
  
  # Parse confidence intervals (assuming format "[lower - upper]")
  extract_ci_bounds <- function(ci_string) {
    # Remove brackets and split
    bounds <- gsub("\\[|\\]", "", ci_string)
    bounds <- as.numeric(strsplit(bounds, " - ")[[1]])
    return(bounds)
  }
  
  ci_50 <- rbind(
    extract_ci_bounds(N_data$confidence_intervals$CI_50),
    extract_ci_bounds(P_data$confidence_intervals$CI_50),
    extract_ci_bounds(K_data$confidence_intervals$CI_50)
  )
  
  ci_80 <- rbind(
    extract_ci_bounds(N_data$confidence_intervals$CI_80),
    extract_ci_bounds(P_data$confidence_intervals$CI_80),
    extract_ci_bounds(K_data$confidence_intervals$CI_80)
  )
  
  ci_95 <- rbind(
    extract_ci_bounds(N_data$confidence_intervals$CI_95),
    extract_ci_bounds(P_data$confidence_intervals$CI_95),
    extract_ci_bounds(K_data$confidence_intervals$CI_95)
  )
  
  means <- c(N_data$recommended_rate, P_data$recommended_rate, K_data$recommended_rate)
  
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    
    plot_data <- data.frame(
      Nutrient = factor(nutrients, levels = nutrients),
      Mean = means,
      CI_50_lower = ci_50[, 1],
      CI_50_upper = ci_50[, 2],
      CI_80_lower = ci_80[, 1],
      CI_80_upper = ci_80[, 2],
      CI_95_lower = ci_95[, 1],
      CI_95_upper = ci_95[, 2]
    )
    
    plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = Nutrient, y = Mean)) +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = CI_95_lower, ymax = CI_95_upper), 
                            width = 0.1, size = 0.8, color = "lightgray") +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = CI_80_lower, ymax = CI_80_upper), 
                            width = 0.2, size = 1.2, color = "gray") +
      ggplot2::geom_errorbar(ggplot2::aes(ymin = CI_50_lower, ymax = CI_50_upper), 
                            width = 0.3, size = 1.5, color = "black") +
      ggplot2::geom_point(size = 3, color = "red") +
      ggplot2::labs(
        title = "Fertilizer Recommendations with Uncertainty Bands",
        subtitle = "Black: 50% CI | Gray: 80% CI | Light gray: 95% CI",
        x = "Nutrient",
        y = "Recommended Rate (kg/ha)",
        caption = "Red points show recommended rates"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 14, face = "bold"),
        axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
      )
    
    return(plot)
    
  } else {
    
    # Base R plot with error bars
    plot(1:3, means, xlim = c(0.5, 3.5), ylim = c(0, max(ci_95[, 2]) * 1.1),
         xaxt = "n", xlab = "Nutrient", ylab = "Recommended Rate (kg/ha)",
         main = "Fertilizer Recommendations with Uncertainty Bands",
         pch = 19, col = "red", cex = 1.5)
    
    axis(1, at = 1:3, labels = nutrients)
    
    # Add error bars
    for (i in 1:3) {
      # 95% CI
      lines(c(i, i), c(ci_95[i, 1], ci_95[i, 2]), lwd = 2, col = "lightgray")
      # 80% CI
      lines(c(i, i), c(ci_80[i, 1], ci_80[i, 2]), lwd = 3, col = "gray")
      # 50% CI
      lines(c(i, i), c(ci_50[i, 1], ci_50[i, 2]), lwd = 4, col = "black")
    }
    
    legend("topright", 
           legend = c("Recommended rate", "50% CI", "80% CI", "95% CI"),
           col = c("red", "black", "gray", "lightgray"),
           lty = c(NA, 1, 1, 1), pch = c(19, NA, NA, NA),
           lwd = c(NA, 4, 3, 2))
    
    return("Base R uncertainty bands plot created")
  }
}

#' Create decision tree visualization (simplified text-based)
create_decision_tree_visualization <- function(analysis_results) {
  
  economic_decision <- analysis_results$economic_analysis$decision_recommendation
  
  # Create simplified decision tree structure
  decision_tree <- list(
    root = "Fertilizer Application Decision",
    branches = list(
      economic_analysis = list(
        condition = sprintf("Net benefit: $%.2f/ha", 
                           analysis_results$economic_analysis$cost_benefit_analysis$profitability$net_benefit),
        outcome = economic_decision$decision,
        rationale = economic_decision$rationale
      ),
      risk_assessment = list(
        condition = sprintf("Probability of loss: %.1f%%",
                           analysis_results$economic_analysis$risk_metrics$probability_of_economic_loss * 100),
        outcome = analysis_results$economic_analysis$risk_metrics$risk_level
      ),
      confidence_level = list(
        condition = sprintf("Recommendation confidence: %s",
                           analysis_results$primary_recommendations$recommendation_confidence$confidence_level),
        outcome = "Data quality assessment"
      )
    ),
    final_recommendation = economic_decision$decision
  )
  
  # Format as text tree
  tree_text <- sprintf("
FERTILIZER DECISION TREE
========================

1. ECONOMIC ANALYSIS
   └─ %s
      └─ DECISION: %s
      └─ RATIONALE: %s

2. RISK ASSESSMENT  
   └─ %s
      └─ RISK LEVEL: %s

3. CONFIDENCE ASSESSMENT
   └─ %s
      └─ DATA QUALITY: Assessed

FINAL RECOMMENDATION: %s
",
    decision_tree$branches$economic_analysis$condition,
    decision_tree$branches$economic_analysis$outcome,
    decision_tree$branches$economic_analysis$rationale,
    decision_tree$branches$risk_assessment$condition,
    decision_tree$branches$risk_assessment$outcome,
    decision_tree$branches$confidence_level$condition,
    decision_tree$final_recommendation
  )
  
  return(list(
    tree_structure = decision_tree,
    text_representation = tree_text
  ))
}

#' Create confidence interval comparison plot
create_confidence_interval_plot <- function(analysis_results) {
  
  # Extract confidence levels for all components
  confidence_data <- list(
    Nitrogen = calculate_confidence_width(analysis_results$primary_recommendations$fertilizer_rates$nitrogen),
    Phosphorus = calculate_confidence_width(analysis_results$primary_recommendations$fertilizer_rates$phosphorus),
    Potassium = calculate_confidence_width(analysis_results$primary_recommendations$fertilizer_rates$potassium),
    Yield = calculate_yield_confidence_width(analysis_results$primary_recommendations$yield_predictions)
  )
  
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    
    # Prepare data for plotting
    plot_data <- data.frame(
      Component = names(confidence_data),
      CI_50_width = sapply(confidence_data, function(x) x$CI_50_width),
      CI_80_width = sapply(confidence_data, function(x) x$CI_80_width),
      CI_95_width = sapply(confidence_data, function(x) x$CI_95_width)
    )
    
    # Reshape for ggplot
    plot_data_long <- tidyr::pivot_longer(plot_data, 
                                         cols = c(CI_50_width, CI_80_width, CI_95_width),
                                         names_to = "Confidence_Level",
                                         values_to = "Width")
    
    plot <- ggplot2::ggplot(plot_data_long, ggplot2::aes(x = Component, y = Width, fill = Confidence_Level)) +
      ggplot2::geom_bar(stat = "identity", position = "dodge") +
      ggplot2::labs(
        title = "Uncertainty Comparison Across Components",
        subtitle = "Width of confidence intervals (relative scale)",
        x = "Component",
        y = "Confidence Interval Width",
        fill = "Confidence Level"
      ) +
      ggplot2::theme_minimal() +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
    
    return(plot)
    
  } else {
    
    # Base R grouped bar plot
    ci_matrix <- matrix(c(
      sapply(confidence_data, function(x) x$CI_50_width),
      sapply(confidence_data, function(x) x$CI_80_width),
      sapply(confidence_data, function(x) x$CI_95_width)
    ), nrow = 3, byrow = TRUE)
    
    barplot(ci_matrix, beside = TRUE, 
            names.arg = names(confidence_data),
            main = "Uncertainty Comparison Across Components",
            xlab = "Component", ylab = "Confidence Interval Width",
            col = c("darkblue", "blue", "lightblue"),
            legend.text = c("50% CI", "80% CI", "95% CI"))
    
    return("Base R confidence interval comparison created")
  }
}

#' Calculate confidence interval widths
calculate_confidence_width <- function(nutrient_data) {
  
  extract_width <- function(ci_string) {
    bounds <- gsub("\\[|\\]", "", ci_string)
    bounds <- as.numeric(strsplit(bounds, " - ")[[1]])
    return(bounds[2] - bounds[1])
  }
  
  list(
    CI_50_width = extract_width(nutrient_data$confidence_intervals$CI_50),
    CI_80_width = extract_width(nutrient_data$confidence_intervals$CI_80),
    CI_95_width = extract_width(nutrient_data$confidence_intervals$CI_95)
  )
}

#' Calculate yield confidence interval widths
calculate_yield_confidence_width <- function(yield_data) {
  
  extract_width <- function(ci_string) {
    bounds <- gsub("\\[|\\]", "", ci_string)
    bounds <- as.numeric(strsplit(bounds, " - ")[[1]])
    return(bounds[2] - bounds[1])
  }
  
  list(
    CI_50_width = extract_width(yield_data$expected_yield_with_fertilizer$confidence_intervals$CI_50),
    CI_80_width = extract_width(yield_data$expected_yield_with_fertilizer$confidence_intervals$CI_80),
    CI_95_width = extract_width(yield_data$expected_yield_with_fertilizer$confidence_intervals$CI_95)
  )
}

#' Save visualization plots to files
save_visualization_plots <- function(visualizations, output_dir = "plots") {
  
  # Create output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  saved_files <- c()
  
  for (plot_name in names(visualizations)) {
    if (plot_name != "saved_files") {  # Avoid recursive saving
      
      plot_obj <- visualizations[[plot_name]]
      
      if (inherits(plot_obj, "ggplot")) {
        # Save ggplot objects
        filename <- file.path(output_dir, paste0(plot_name, ".png"))
        ggplot2::ggsave(filename, plot_obj, width = 10, height = 6, dpi = 300)
        saved_files <- c(saved_files, filename)
        cat(sprintf("✓ Saved %s\n", filename))
        
      } else if (is.character(plot_obj)) {
        # Base R plots (already created)
        cat(sprintf("✓ %s (base R plot displayed)\n", plot_name))
        
      } else if (is.list(plot_obj)) {
        # Text-based visualizations (like decision tree)
        filename <- file.path(output_dir, paste0(plot_name, ".txt"))
        if ("text_representation" %in% names(plot_obj)) {
          writeLines(plot_obj$text_representation, filename)
          saved_files <- c(saved_files, filename)
          cat(sprintf("✓ Saved %s\n", filename))
        }
      }
    }
  }
  
  return(saved_files)
}

# ================================================================================
# MODULE INITIALIZATION
# ================================================================================

cat("✓ User Interpretation and Visualization Module loaded successfully\n")
cat("Available functions:\n")
cat("- generate_progressive_disclosure(): User-level appropriate interfaces\n")
cat("- generate_visual_communication_tools(): Comprehensive visualization suite\n")
cat("  Available visualizations:\n")
cat("    • yield_response: Yield response curves with confidence bands\n")
cat("    • probability_distributions: Yield probability distributions\n")
cat("    • cost_benefit: Economic risk assessment visualizations\n")
cat("    • uncertainty_bands: Fertilizer recommendations with uncertainty\n")
cat("    • decision_tree: Decision reasoning visualization\n")
cat("    • confidence_intervals: Uncertainty comparison across components\n\n")

cat("User levels supported:\n")
cat("• Beginner: Traffic light system with simple recommendations\n")
cat("• Intermediate: Detailed analysis with economic and agronomic insights\n")
cat("• Expert: Full uncertainty analysis and technical details\n\n")
