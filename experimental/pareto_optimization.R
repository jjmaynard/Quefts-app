# EXPERIMENTAL / NOT INTEGRATED
# This module sketches a multi-objective (NSGA-II) land-use optimizer for a
# future GAEZ-QUEFTS integration. It is not source()-d by any other file in
# this project, depends on the `nsga2R` package (used nowhere else here),
# and operates only on synthetic demo data (see run_land_use_optimization()).
# Treat as a design sketch, not production code, until it is either wired
# into integrated_decision_support.R or removed.

# Required libraries
library(nsga2R)  # For multi-objective optimization
library(dplyr)
library(ggplot2)
library(plotly)

# Main optimization framework
optimize_land_use <- function(region_data) {
  
  # Define objectives (to be maximized - we'll convert minimization later)
  objectives <- list(
    maximize_yield = TRUE,
    minimize_environmental_impact = TRUE,  # Will be converted to maximize
    maximize_economic_return = TRUE,
    ensure_sustainability = TRUE
  )
  
  # Constraints
  constraints <- list(
    water_availability = region_data$water_budget,
    fertilizer_access = region_data$input_supply,
    market_access = region_data$infrastructure,
    farmer_capacity = region_data$technical_knowledge
  )
  
  # Optimization using GAEZ-QUEFTS integration
  optimal_solutions <- pareto_optimization(
    suitability_data = region_data$gaez_quefts,
    objectives = objectives,
    constraints = constraints
  )
  
  return(optimal_solutions)
}

# Core Pareto optimization function
pareto_optimization <- function(suitability_data, objectives, constraints, 
                                pop_size = 100, generations = 200) {
  
  # Define the multi-objective function
  multi_objective_function <- function(x) {
    # x represents land use allocation decisions (e.g., crop types, areas)
    
    # Calculate yield based on suitability and allocation
    yield_score <- calculate_yield(x, suitability_data)
    
    # Calculate environmental impact (lower is better, so we'll negate it)
    env_impact <- calculate_environmental_impact(x, suitability_data)
    
    # Calculate economic return
    economic_return <- calculate_economic_return(x, suitability_data)
    
    # Calculate sustainability score
    sustainability <- calculate_sustainability(x, suitability_data)
    
    # Return objectives (NSGA-II maximizes, so negate minimization objectives)
    return(c(
      yield_score,
      -env_impact,  # Negate because we want to minimize
      economic_return,
      sustainability
    ))
  }
  
  # Define constraint function
  constraint_function <- function(x) {
    violations <- c()
    
    # Water constraint
    water_usage <- sum(x * suitability_data$water_requirement)
    violations <- c(violations, max(0, water_usage - constraints$water_availability))
    
    # Fertilizer constraint
    fertilizer_usage <- sum(x * suitability_data$fertilizer_requirement)
    violations <- c(violations, max(0, fertilizer_usage - constraints$fertilizer_access))
    
    # Market access constraint (minimum threshold)
    violations <- c(violations, max(0, 0.5 - constraints$market_access))
    
    # Technical capacity constraint
    complexity_score <- sum(x * suitability_data$technical_complexity)
    violations <- c(violations, max(0, complexity_score - constraints$farmer_capacity))
    
    return(sum(violations))  # Return total constraint violation
  }
  
  # Define bounds for decision variables (land allocation proportions)
  n_vars <- nrow(suitability_data)
  lower_bounds <- rep(0, n_vars)
  upper_bounds <- rep(1, n_vars)
  
  # Run NSGA-II optimization
  result <- nsga2R(
    fn = multi_objective_function,
    varNo = n_vars,
    objDim = 4,  # 4 objectives
    lowerBounds = lower_bounds,
    upperBounds = upper_bounds,
    popSize = pop_size,
    generations = generations,
    cprob = 0.8,  # Crossover probability
    mprob = 0.1   # Mutation probability
  )
  
  # Process results
  pareto_solutions <- extract_pareto_solutions(result, suitability_data)
  
  return(pareto_solutions)
}

# Helper functions for objective calculations
calculate_yield <- function(allocation, suitability_data) {
  # Weighted yield based on suitability and allocation
  total_yield <- sum(allocation * suitability_data$yield_potential * 
                       suitability_data$suitability_index)
  return(total_yield)
}

calculate_environmental_impact <- function(allocation, suitability_data) {
  # Environmental impact based on land use intensity and fragmentation
  impact_score <- sum(allocation * suitability_data$environmental_cost) +
    calculate_fragmentation_penalty(allocation)
  return(impact_score)
}

calculate_economic_return <- function(allocation, suitability_data) {
  # Net economic return considering costs and revenues
  revenue <- sum(allocation * suitability_data$yield_potential * 
                   suitability_data$market_price)
  costs <- sum(allocation * suitability_data$production_cost)
  return(revenue - costs)
}

calculate_sustainability <- function(allocation, suitability_data) {
  # Sustainability index based on soil health, biodiversity, etc.
  sustainability_score <- sum(allocation * suitability_data$sustainability_index)
  return(sustainability_score)
}

calculate_fragmentation_penalty <- function(allocation) {
  # Simple fragmentation penalty (could be more sophisticated)
  # Penalize scattered small allocations
  active_plots <- sum(allocation > 0.01)  # Count significantly used plots
  fragmentation_penalty <- active_plots * 0.1
  return(fragmentation_penalty)
}

# Extract and format Pareto solutions
extract_pareto_solutions <- function(nsga_result, suitability_data) {
  
  # Get Pareto front solutions
  pareto_indices <- which(nsga_result$paretoFrontRank == 1)
  pareto_vars <- nsga_result$parameters[pareto_indices, , drop = FALSE]
  pareto_objs <- nsga_result$objectives[pareto_indices, , drop = FALSE]
  
  # Create results data frame
  solutions <- data.frame(
    solution_id = 1:length(pareto_indices),
    yield = pareto_objs[, 1],
    env_impact = -pareto_objs[, 2],  # Convert back to positive (lower is better)
    economic_return = pareto_objs[, 3],
    sustainability = pareto_objs[, 4]
  )
  
  # Add allocation details
  allocation_matrix <- pareto_vars
  colnames(allocation_matrix) <- paste0("plot_", 1:ncol(allocation_matrix))
  
  result <- list(
    pareto_front = solutions,
    allocations = allocation_matrix,
    summary_stats = calculate_solution_stats(solutions),
    trade_offs = analyze_trade_offs(solutions)
  )
  
  return(result)
}

# Analysis functions
calculate_solution_stats <- function(solutions) {
  stats <- data.frame(
    objective = c("yield", "env_impact", "economic_return", "sustainability"),
    min_value = c(min(solutions$yield), min(solutions$env_impact),
                  min(solutions$economic_return), min(solutions$sustainability)),
    max_value = c(max(solutions$yield), max(solutions$env_impact),
                  max(solutions$economic_return), max(solutions$sustainability)),
    range_span = c(max(solutions$yield) - min(solutions$yield),
                   max(solutions$env_impact) - min(solutions$env_impact),
                   max(solutions$economic_return) - min(solutions$economic_return),
                   max(solutions$sustainability) - min(solutions$sustainability))
  )
  return(stats)
}

analyze_trade_offs <- function(solutions) {
  # Calculate correlation matrix to identify trade-offs
  cor_matrix <- cor(solutions[, c("yield", "env_impact", "economic_return", "sustainability")])
  
  # Identify strongest trade-offs (negative correlations)
  trade_offs <- list()
  for(i in 1:(ncol(cor_matrix)-1)) {
    for(j in (i+1):ncol(cor_matrix)) {
      if(cor_matrix[i,j] < -0.3) {  # Threshold for significant trade-off
        trade_offs[[length(trade_offs) + 1]] <- list(
          objectives = c(rownames(cor_matrix)[i], colnames(cor_matrix)[j]),
          correlation = cor_matrix[i,j]
        )
      }
    }
  }
  
  return(trade_offs)
}

# Visualization functions
plot_pareto_front <- function(optimization_result) {
  solutions <- optimization_result$pareto_front
  
  # 2D plots for key trade-offs
  p1 <- ggplot(solutions, aes(x = yield, y = env_impact)) +
    geom_point(color = "blue", alpha = 0.7) +
    labs(title = "Yield vs Environmental Impact Trade-off",
         x = "Crop Yield", y = "Environmental Impact") +
    theme_minimal()
  
  p2 <- ggplot(solutions, aes(x = economic_return, y = sustainability)) +
    geom_point(color = "green", alpha = 0.7) +
    labs(title = "Economic Return vs Sustainability Trade-off",
         x = "Economic Return", y = "Sustainability Score") +
    theme_minimal()
  
  # 3D interactive plot
  p3 <- plot_ly(solutions, x = ~yield, y = ~economic_return, z = ~sustainability,
                color = ~env_impact, colors = viridis::viridis(10),
                type = "scatter3d", mode = "markers") %>%
    layout(title = "3D Pareto Front Visualization",
           scene = list(xaxis = list(title = "Yield"),
                        yaxis = list(title = "Economic Return"),
                        zaxis = list(title = "Sustainability")))
  
  return(list(yield_vs_env = p1, econ_vs_sustain = p2, interactive_3d = p3))
}

# Example usage function
run_land_use_optimization <- function() {
  # Example data structure (would be loaded from real GAEZ-QUEFTS data)
  region_data <- list(
    water_budget = 1000,  # mm/year
    input_supply = 500,   # kg/ha fertilizer
    infrastructure = 0.7, # access index (0-1)
    technical_knowledge = 0.6, # capacity index (0-1)
    gaez_quefts = data.frame(
      plot_id = 1:20,
      yield_potential = runif(20, 2, 8),  # tons/ha
      suitability_index = runif(20, 0.3, 1.0),
      environmental_cost = runif(20, 0.1, 0.8),
      market_price = runif(20, 200, 500),  # $/ton
      production_cost = runif(20, 300, 800), # $/ha
      sustainability_index = runif(20, 0.4, 0.9),
      water_requirement = runif(20, 300, 800), # mm/year
      fertilizer_requirement = runif(20, 50, 150), # kg/ha
      technical_complexity = runif(20, 0.2, 0.8)
    )
  )
  
  # Run optimization
  results <- optimize_land_use(region_data)
  
  # Generate visualizations
  plots <- plot_pareto_front(results)
  
  return(list(optimization_results = results, visualizations = plots))
}

# Print summary function
print_optimization_summary <- function(results) {
  cat("=== Land Use Optimization Results ===\n\n")
  cat("Number of Pareto-optimal solutions found:", nrow(results$pareto_front), "\n\n")
  
  cat("Objective ranges:\n")
  print(results$summary_stats)
  
  cat("\nKey trade-offs identified:\n")
  for(i in seq_along(results$trade_offs)) {
    trade_off <- results$trade_offs[[i]]
    cat(sprintf("- %s vs %s (correlation: %.3f)\n", 
                trade_off$objectives[1], trade_off$objectives[2], 
                trade_off$correlation))
  }
}