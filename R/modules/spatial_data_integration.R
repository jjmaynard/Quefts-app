# ================================================================================
# SPATIAL DATA INTEGRATION MODULE
# Multi-scale soil information from global maps to site-specific data
# ================================================================================

# Required packages for spatial data integration
spatial_packages <- c("sf", "raster", "terra", "httr", "jsonlite", "dplyr", "magrittr")

for (pkg in spatial_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste("Installing", pkg, "package..."))
    install.packages(pkg)
  }
}

# Load required packages
suppressMessages({
  library(sf)
  library(raster)
  library(terra)
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(magrittr)
})

# ================================================================================
# 1. GLOBAL SOIL DATA INTEGRATION (TIER 1)
# ================================================================================

#' Fetch soil properties from SoilGrids API
#' 
#' @param lat Latitude coordinate
#' @param lon Longitude coordinate
#' @param properties Vector of soil properties to fetch
#' @param depths Vector of depth layers
#' @return List containing soil properties with uncertainty estimates
fetch_soilgrids_data <- function(lat, lon,
                                properties = c("phh2o", "soc", "nitrogen", "bdod", "clay", "sand"),
                                # convert_soilgrids_to_quefts() (below) only ever reads the "0-5cm"
                                # entry of each property -- 5-15cm/15-30cm are fetched and parsed but
                                # never used. Requesting them anyway triples the number of
                                # property/depth layers ISRIC's backend has to look up per call,
                                # which was making an already-slow endpoint more likely to blow past
                                # its own gateway's timeout (observed as sporadic 504s).
                                depths = c("0-5cm"),
                                max_retries = 3,
                                request_timeout_s = 20) {

  # SoilGrids REST API endpoint
  base_url <- "https://rest.isric.org/soilgrids/v2.0/properties/query"

  # Construct query parameters. SoilGrids' API requires each multi-valued
  # parameter (property/depth/value) repeated once per value
  # (?property=phh2o&property=soc&...) -- comma-joining them into a single
  # string (paste(..., collapse=",")), as this used to do, produces a
  # request the API responds to with a 500 for every combination of two or
  # more properties. This was previously masked as "SoilGrids API
  # flakiness" (see PROJECT_EVALUATION.md Sec 6.3) but is fully
  # reproducible and had nothing to do with the live API being unreliable
  # -- see PROJECT_TRACKER.md Phase 7 for how this was found.
  query_params <- c(
    list(lon = lon, lat = lat),
    setNames(as.list(properties), rep("property", length(properties))),
    setNames(as.list(depths), rep("depth", length(depths))),
    setNames(as.list(c("mean", "uncertainty")), rep("value", 2))
  )

  # SoilGrids' REST API is a shared, rate-limited public service and
  # occasionally returns transient 502/503/504s under load. A single failed
  # attempt was surfacing as "Could not retrieve soil data for this
  # location" even when a retry a second later would have succeeded, so
  # retry transient errors with a short exponential backoff before giving up.
  for (attempt in seq_len(max_retries)) {
    result <- tryCatch({
      response <- GET(base_url, query = query_params, timeout(request_timeout_s))
      status <- status_code(response)

      if (status == 200) {
        data <- fromJSON(content(response, "text", encoding = "UTF-8"))
        soil_data <- extract_soilgrids_properties(data, properties, depths)

        soil_data$source <- "SoilGrids_250m"
        soil_data$uncertainty_tier <- 1  # Highest uncertainty
        soil_data$spatial_resolution <- "250m"
        soil_data$coordinates <- list(lat = lat, lon = lon)
        soil_data$fetch_date <- Sys.Date()

        list(soil_data = soil_data, retryable = FALSE)
      } else if (status %in% c(502, 503, 504) && attempt < max_retries) {
        list(soil_data = NULL, retryable = TRUE, status = status)
      } else {
        warning(paste("SoilGrids API request failed with status:", status))
        list(soil_data = NULL, retryable = FALSE)
      }
    }, error = function(e) {
      if (attempt < max_retries) {
        list(soil_data = NULL, retryable = TRUE, message = e$message)
      } else {
        warning(paste("Error fetching SoilGrids data:", e$message))
        list(soil_data = NULL, retryable = FALSE)
      }
    })

    if (!is.null(result$soil_data)) {
      return(result$soil_data)
    }
    if (!isTRUE(result$retryable)) {
      return(NULL)
    }

    Sys.sleep(2^(attempt - 1))  # 1s, 2s, 4s, ...
  }

  NULL
}

#' Extract and process SoilGrids properties
extract_soilgrids_properties <- function(data, properties, depths) {

  soil_properties <- list()
  uncertainty_estimates <- list()

  # jsonlite parses the API's "layers" JSON array into a data.frame (one row
  # per property, with a list-column "depths" holding a further per-depth
  # data.frame) -- not a list keyed by property name. data$properties$layers[[prop]]
  # (indexing a data.frame by a property-name string) always returns NULL,
  # so this function previously never extracted any real values even from a
  # successful 200 response. See PROJECT_TRACKER.md Phase 7.
  layers <- data$properties$layers
  if (is.null(layers) || nrow(layers) == 0) {
    return(convert_soilgrids_to_quefts(soil_properties, uncertainty_estimates))
  }

  for (prop in properties) {
    prop_row <- layers[layers$name == prop, ]

    if (nrow(prop_row) > 0) {
      # depths is a list-column; prop_row$depths[[1]] is the per-depth data.frame.
      depths_df <- prop_row$depths[[1]]

      depths_data <- list()
      uncertainties <- list()

      for (depth in depths) {
        depth_idx <- which(depths_df$label == depth)
        if (length(depth_idx) > 0) {
          depths_data[[depth]] <- depths_df$values$mean[depth_idx]
          uncertainties[[depth]] <- depths_df$values$uncertainty[depth_idx]
        }
      }

      soil_properties[[prop]] <- depths_data
      uncertainty_estimates[[prop]] <- uncertainties
    }
  }

  # Convert to QUEFTS-compatible format
  quefts_data <- convert_soilgrids_to_quefts(soil_properties, uncertainty_estimates)
  
  return(quefts_data)
}

#' Convert SoilGrids data to QUEFTS format
convert_soilgrids_to_quefts <- function(properties, uncertainties) {
  
  # Get surface layer (0-5cm) as primary
  surface_depth <- "0-5cm"
  
  quefts_soil <- list()
  uncertainty_soil <- list()
  
  # pH conversion (from pH*10 to pH)
  if ("phh2o" %in% names(properties)) {
    quefts_soil$pH <- properties$phh2o[[surface_depth]] / 10
    uncertainty_soil$pH <- uncertainties$phh2o[[surface_depth]] / 10
  }
  
  # Organic Carbon (g/kg)
  if ("soc" %in% names(properties)) {
    quefts_soil$SOC <- properties$soc[[surface_depth]] / 10  # Convert from g/kg*10
    uncertainty_soil$SOC <- uncertainties$soc[[surface_depth]] / 10
  }
  
  # Nitrogen (g/kg) - estimate if not available
  if ("nitrogen" %in% names(properties)) {
    quefts_soil$Total_N <- properties$nitrogen[[surface_depth]] / 100  # Convert from mg/kg
    uncertainty_soil$Total_N <- uncertainties$nitrogen[[surface_depth]] / 100
  } else {
    # Estimate N from SOC using C:N ratio of 12:1
    quefts_soil$Total_N <- quefts_soil$SOC / 12
    uncertainty_soil$Total_N <- uncertainty_soil$SOC / 12
  }
  
  # Bulk density (kg/dm³ to g/cm³)
  if ("bdod" %in% names(properties)) {
    quefts_soil$bulk_density <- properties$bdod[[surface_depth]] / 100
    uncertainty_soil$bulk_density <- uncertainties$bdod[[surface_depth]] / 100
  }
  
  # Texture
  if ("clay" %in% names(properties) && "sand" %in% names(properties)) {
    clay_pct <- properties$clay[[surface_depth]] / 10
    sand_pct <- properties$sand[[surface_depth]] / 10
    silt_pct <- 100 - clay_pct - sand_pct
    
    quefts_soil$clay <- clay_pct
    quefts_soil$sand <- sand_pct
    quefts_soil$silt <- silt_pct
    
    uncertainty_soil$clay <- uncertainties$clay[[surface_depth]] / 10
    uncertainty_soil$sand <- uncertainties$sand[[surface_depth]] / 10
    uncertainty_soil$silt <- sqrt(uncertainty_soil$clay^2 + uncertainty_soil$sand^2)
  }
  
  # Estimate missing QUEFTS parameters from available data
  estimated_params <- estimate_missing_quefts_params(quefts_soil, uncertainty_soil)
  
  return(list(
    soil_properties = c(quefts_soil, estimated_params$properties),
    uncertainties = c(uncertainty_soil, estimated_params$uncertainties),
    data_quality = "global_maps",
    uncertainty_level = "high"
  ))
}

#' Estimate missing QUEFTS parameters using pedotransfer functions
estimate_missing_quefts_params <- function(soil_props, uncertainties) {
  
  estimated <- list()
  est_uncertainties <- list()
  
  # Estimate Olsen P from general relationships (very uncertain)
  if (!"Olsen_P" %in% names(soil_props)) {
    # Use global average with high uncertainty for tropical soils
    estimated$Olsen_P <- 8.0  # mg/kg - typical for tropical soils
    est_uncertainties$Olsen_P <- 6.0  # ±75% uncertainty
  }
  
  # Estimate exchangeable K from clay content if available
  if (!"Exch_K" %in% names(soil_props) && "clay" %in% names(soil_props)) {
    # Rough estimate: 0.15 * clay% (in mmol/kg)
    estimated$Exch_K <- soil_props$clay * 0.15
    est_uncertainties$Exch_K <- estimated$Exch_K * 0.8  # ±80% uncertainty
  } else if (!"Exch_K" %in% names(soil_props)) {
    # Default estimate for tropical soils
    estimated$Exch_K <- 5.0  # mmol/kg
    est_uncertainties$Exch_K <- 4.0  # ±80% uncertainty
  }
  
  # Estimate CEC if needed
  if (!"CEC" %in% names(soil_props) && "clay" %in% names(soil_props) && "SOC" %in% names(soil_props)) {
    # CEC = 0.6 * clay% + 2.0 * SOC% (rough estimate)
    estimated$CEC <- 0.6 * soil_props$clay + 2.0 * soil_props$SOC
    est_uncertainties$CEC <- estimated$CEC * 0.3  # ±30% uncertainty
  }
  
  return(list(
    properties = estimated,
    uncertainties = est_uncertainties
  ))
}

# ================================================================================
# 2. REGIONAL/NATIONAL REFINEMENT (TIER 2)
# ================================================================================

#' Refine global soil data with regional information
#' 
#' @param global_data Output from fetch_soilgrids_data
#' @param region Region code or country code
#' @param soil_survey_data Optional local soil survey data
refine_with_regional_data <- function(global_data, region = NULL, soil_survey_data = NULL) {
  
  if (is.null(global_data)) {
    warning("No global data provided for refinement")
    return(NULL)
  }
  
  refined_data <- global_data
  
  # Apply regional calibration factors if available
  regional_factors <- get_regional_calibration_factors(region)
  
  if (!is.null(regional_factors)) {
    refined_data <- apply_regional_calibration(refined_data, regional_factors)
    refined_data$uncertainty_tier <- 2  # Reduced uncertainty
    refined_data$data_quality <- "regional_refined"
    refined_data$uncertainty_level <- "medium"
  }
  
  # Incorporate soil survey data if available
  if (!is.null(soil_survey_data)) {
    refined_data <- incorporate_soil_survey_data(refined_data, soil_survey_data)
  }
  
  # Update spatial resolution
  refined_data$spatial_resolution <- "10-100m"
  
  return(refined_data)
}

#' Get regional calibration factors
get_regional_calibration_factors <- function(region) {
  
  # Regional calibration factors (example for different regions)
  calibration_factors <- list(
    "Sub-Saharan_Africa" = list(
      pH_bias = -0.2,        # Global maps tend to overestimate pH
      SOC_factor = 0.8,      # Tend to overestimate SOC
      P_bias = -2.0,         # Underestimate available P
      K_factor = 1.2         # Underestimate exchangeable K
    ),
    "Southeast_Asia" = list(
      pH_bias = -0.3,
      SOC_factor = 0.9,
      P_bias = -1.5,
      K_factor = 1.1
    ),
    "Latin_America" = list(
      pH_bias = -0.1,
      SOC_factor = 0.85,
      P_bias = -1.0,
      K_factor = 1.15
    )
  )
  
  return(calibration_factors[[region]])
}

#' Apply regional calibration to soil data
apply_regional_calibration <- function(data, factors) {
  
  calibrated <- data
  
  # Apply calibration factors
  if (!is.null(factors$pH_bias)) {
    calibrated$soil_properties$pH <- calibrated$soil_properties$pH + factors$pH_bias
    # Reduce uncertainty due to regional calibration
    calibrated$uncertainties$pH <- calibrated$uncertainties$pH * 0.8
  }
  
  if (!is.null(factors$SOC_factor)) {
    calibrated$soil_properties$SOC <- calibrated$soil_properties$SOC * factors$SOC_factor
    calibrated$uncertainties$SOC <- calibrated$uncertainties$SOC * 0.7
  }
  
  if (!is.null(factors$P_bias)) {
    calibrated$soil_properties$Olsen_P <- calibrated$soil_properties$Olsen_P + factors$P_bias
    calibrated$uncertainties$Olsen_P <- calibrated$uncertainties$Olsen_P * 0.8
  }
  
  if (!is.null(factors$K_factor)) {
    calibrated$soil_properties$Exch_K <- calibrated$soil_properties$Exch_K * factors$K_factor
    calibrated$uncertainties$Exch_K <- calibrated$uncertainties$Exch_K * 0.75
  }
  
  return(calibrated)
}

# ================================================================================
# 3. SITE-SPECIFIC OBSERVATIONS (TIER 3)
# ================================================================================

#' Incorporate field observations to reduce uncertainty
#' 
#' @param regional_data Output from regional refinement
#' @param field_observations List of field observations
#' @param farmer_knowledge Local farmer knowledge and history
incorporate_field_observations <- function(regional_data, field_observations, farmer_knowledge = NULL) {
  
  if (is.null(regional_data)) {
    warning("No regional data provided for field observation integration")
    return(NULL)
  }
  
  updated_data <- regional_data
  
  # Process visual soil assessment
  if (!is.null(field_observations$visual_assessment)) {
    updated_data <- update_from_visual_assessment(updated_data, field_observations$visual_assessment)
  }
  
  # Process simple field tests
  if (!is.null(field_observations$field_tests)) {
    updated_data <- update_from_field_tests(updated_data, field_observations$field_tests)
  }
  
  # Incorporate crop performance history
  if (!is.null(field_observations$crop_history)) {
    updated_data <- validate_with_crop_history(updated_data, field_observations$crop_history)
  }
  
  # Update data quality indicators
  updated_data$uncertainty_tier <- 3
  updated_data$data_quality <- "field_observed"
  updated_data$uncertainty_level <- "low"
  updated_data$spatial_resolution <- "field_specific"
  
  # Reduce uncertainties significantly
  updated_data$uncertainties <- lapply(updated_data$uncertainties, function(x) x * 0.5)
  
  return(updated_data)
}

#' Update soil data from visual assessment
update_from_visual_assessment <- function(data, visual_assessment) {
  
  updated <- data
  
  # Soil color indicates organic matter
  if (!is.null(visual_assessment$soil_color)) {
    color_factor <- estimate_om_from_color(visual_assessment$soil_color)
    
    # Adjust SOC estimate
    updated$soil_properties$SOC <- updated$soil_properties$SOC * color_factor
    updated$uncertainties$SOC <- updated$uncertainties$SOC * 0.7  # Reduced uncertainty
  }
  
  # Texture feel test
  if (!is.null(visual_assessment$texture_feel)) {
    texture_update <- estimate_texture_from_feel(visual_assessment$texture_feel)
    
    if (!is.null(texture_update)) {
      updated$soil_properties$clay <- texture_update$clay
      updated$soil_properties$sand <- texture_update$sand
      updated$soil_properties$silt <- texture_update$silt
      
      # Significantly reduce texture uncertainty
      updated$uncertainties$clay <- 5.0  # ±5% uncertainty
      updated$uncertainties$sand <- 5.0
      updated$uncertainties$silt <- 5.0
    }
  }
  
  # Drainage assessment affects K availability
  if (!is.null(visual_assessment$drainage)) {
    drainage_factor <- estimate_drainage_factor(visual_assessment$drainage)
    updated$soil_properties$Exch_K <- updated$soil_properties$Exch_K * drainage_factor
    updated$uncertainties$Exch_K <- updated$uncertainties$Exch_K * 0.8
  }
  
  return(updated)
}

#' Estimate organic matter from soil color
estimate_om_from_color <- function(color_description) {
  
  color_factors <- list(
    "very_dark" = 1.5,
    "dark_brown" = 1.2,
    "brown" = 1.0,
    "light_brown" = 0.8,
    "pale" = 0.6,
    "gray" = 0.7,
    "red" = 0.9
  )
  
  return(color_factors[[color_description]] %||% 1.0)
}

#' Estimate texture from feel test
estimate_texture_from_feel <- function(feel_description) {
  
  texture_classes <- list(
    "sand" = list(clay = 5, sand = 85, silt = 10),
    "loamy_sand" = list(clay = 8, sand = 75, silt = 17),
    "sandy_loam" = list(clay = 12, sand = 65, silt = 23),
    "loam" = list(clay = 18, sand = 40, silt = 42),
    "silt_loam" = list(clay = 15, sand = 25, silt = 60),
    "clay_loam" = list(clay = 30, sand = 35, silt = 35),
    "clay" = list(clay = 55, sand = 25, silt = 20)
  )
  
  return(texture_classes[[feel_description]])
}

#' Estimate drainage factor for K availability
estimate_drainage_factor <- function(drainage_class) {
  
  drainage_factors <- list(
    "very_poor" = 0.6,
    "poor" = 0.7,
    "moderate" = 1.0,
    "well" = 1.2,
    "excessive" = 0.9
  )
  
  return(drainage_factors[[drainage_class]] %||% 1.0)
}

#' Update from simple field tests
update_from_field_tests <- function(data, field_tests) {
  
  updated <- data
  
  # pH test strips
  if (!is.null(field_tests$pH_strip)) {
    updated$soil_properties$pH <- field_tests$pH_strip
    updated$uncertainties$pH <- 0.3  # ±0.3 pH units uncertainty for strips
  }
  
  # Electrical conductivity
  if (!is.null(field_tests$EC)) {
    # EC can indicate nutrient availability
    ec_factor <- estimate_nutrient_factor_from_ec(field_tests$EC)
    updated$soil_properties$Exch_K <- updated$soil_properties$Exch_K * ec_factor
    updated$uncertainties$Exch_K <- updated$uncertainties$Exch_K * 0.9
  }
  
  return(updated)
}

#' Estimate nutrient factor from electrical conductivity
estimate_nutrient_factor_from_ec <- function(ec_value) {
  
  # EC in dS/m - rough relationship with nutrient availability
  if (ec_value < 0.2) {
    return(0.7)  # Low nutrient availability
  } else if (ec_value < 0.8) {
    return(1.0)  # Normal
  } else if (ec_value < 2.0) {
    return(1.3)  # High nutrient availability
  } else {
    return(1.0)  # Very high - may indicate salinity issues
  }
}

# ================================================================================
# 4. LABORATORY DATA INTEGRATION (TIER 4)
# ================================================================================

#' Integrate laboratory soil test results (highest accuracy)
#' 
#' @param field_data Output from field observations
#' @param lab_results Laboratory analysis results
#' @param lab_methods Methods used for analysis
integrate_lab_data <- function(field_data, lab_results, lab_methods = NULL) {
  
  if (is.null(field_data)) {
    warning("No field data provided for lab integration")
    return(NULL)
  }
  
  updated_data <- field_data
  
  # Direct replacement of measured parameters
  if (!is.null(lab_results$pH)) {
    updated_data$soil_properties$pH <- lab_results$pH
    updated_data$uncertainties$pH <- 0.1  # ±0.1 pH units for lab analysis
  }
  
  if (!is.null(lab_results$organic_carbon)) {
    updated_data$soil_properties$SOC <- lab_results$organic_carbon
    updated_data$uncertainties$SOC <- lab_results$organic_carbon * 0.05  # ±5% for lab analysis
  }
  
  if (!is.null(lab_results$olsen_p)) {
    updated_data$soil_properties$Olsen_P <- lab_results$olsen_p
    updated_data$uncertainties$Olsen_P <- lab_results$olsen_p * 0.1  # ±10% for P analysis
  }
  
  if (!is.null(lab_results$exchangeable_k)) {
    updated_data$soil_properties$Exch_K <- lab_results$exchangeable_k
    updated_data$uncertainties$Exch_K <- lab_results$exchangeable_k * 0.05  # ±5% for K analysis
  }
  
  if (!is.null(lab_results$total_nitrogen)) {
    updated_data$soil_properties$Total_N <- lab_results$total_nitrogen
    updated_data$uncertainties$Total_N <- lab_results$total_nitrogen * 0.05
  }
  
  # Update texture if particle size analysis was done
  if (!is.null(lab_results$texture)) {
    updated_data$soil_properties$clay <- lab_results$texture$clay
    updated_data$soil_properties$sand <- lab_results$texture$sand
    updated_data$soil_properties$silt <- lab_results$texture$silt
    
    # Very low uncertainty for lab texture analysis
    updated_data$uncertainties$clay <- 2.0
    updated_data$uncertainties$sand <- 2.0
    updated_data$uncertainties$silt <- 2.0
  }
  
  # Additional parameters if available
  if (!is.null(lab_results$CEC)) {
    updated_data$soil_properties$CEC <- lab_results$CEC
    updated_data$uncertainties$CEC <- lab_results$CEC * 0.05
  }
  
  if (!is.null(lab_results$bulk_density)) {
    updated_data$soil_properties$bulk_density <- lab_results$bulk_density
    updated_data$uncertainties$bulk_density <- lab_results$bulk_density * 0.03
  }
  
  # Update quality indicators
  updated_data$uncertainty_tier <- 4  # Lowest uncertainty
  updated_data$data_quality <- "laboratory_analyzed"
  updated_data$uncertainty_level <- "very_low"
  updated_data$spatial_resolution <- "point_sample"
  updated_data$lab_analysis_date <- Sys.Date()
  
  if (!is.null(lab_methods)) {
    updated_data$analysis_methods <- lab_methods
  }
  
  return(updated_data)
}

# ================================================================================
# 5. SPATIAL DATA MANAGER - MAIN INTERFACE
# ================================================================================

#' Main function to get multi-scale soil data
#' 
#' @param lat Latitude
#' @param lon Longitude
#' @param region Optional region for calibration
#' @param field_observations Optional field observations
#' @param lab_results Optional laboratory results
#' @param data_priority Vector indicating preference for data sources
get_multiscale_soil_data <- function(lat, lon, 
                                    region = NULL,
                                    field_observations = NULL,
                                    lab_results = NULL,
                                    data_priority = c("lab", "field", "regional", "global")) {
  
  cat("Fetching multi-scale soil data for coordinates:", lat, ",", lon, "\n")
  
  # Initialize data progression
  soil_data <- NULL
  data_sources <- list()
  
  # Step 1: Start with global data (Tier 1)
  cat("Fetching global soil maps data...\n")
  global_data <- fetch_soilgrids_data(lat, lon)
  
  if (!is.null(global_data)) {
    soil_data <- global_data
    data_sources$global <- TRUE
    cat("✓ Global data retrieved (uncertainty: high)\n")
  } else {
    warning("Could not retrieve global soil data")
    return(NULL)
  }
  
  # Step 2: Regional refinement (Tier 2)
  if (!is.null(region)) {
    cat("Applying regional calibration...\n")
    regional_data <- refine_with_regional_data(soil_data, region)
    
    if (!is.null(regional_data)) {
      soil_data <- regional_data
      data_sources$regional <- TRUE
      cat("✓ Regional calibration applied (uncertainty: medium)\n")
    }
  }
  
  # Step 3: Field observations (Tier 3)
  if (!is.null(field_observations)) {
    cat("Integrating field observations...\n")
    field_data <- incorporate_field_observations(soil_data, field_observations)
    
    if (!is.null(field_data)) {
      soil_data <- field_data
      data_sources$field <- TRUE
      cat("✓ Field observations integrated (uncertainty: low)\n")
    }
  }
  
  # Step 4: Laboratory data (Tier 4)
  if (!is.null(lab_results)) {
    cat("Integrating laboratory results...\n")
    lab_data <- integrate_lab_data(soil_data, lab_results)
    
    if (!is.null(lab_data)) {
      soil_data <- lab_data
      data_sources$lab <- TRUE
      cat("✓ Laboratory data integrated (uncertainty: very low)\n")
    }
  }
  
  # Add data provenance
  soil_data$data_sources <- data_sources
  soil_data$integration_date <- Sys.time()
  
  # Convert to QUEFTS format
  quefts_input <- convert_to_quefts_input(soil_data)
  
  cat("Data integration complete. Final uncertainty level:", soil_data$uncertainty_level, "\n")
  
  return(list(
    raw_data = soil_data,
    quefts_input = quefts_input,
    data_summary = generate_data_summary(soil_data)
  ))
}

#' Convert integrated soil data to QUEFTS input format
convert_to_quefts_input <- function(integrated_data) {
  
  props <- integrated_data$soil_properties
  
  # Create QUEFTS-compatible soil data
  quefts_soil <- list(
    site_name = paste("Site", round(integrated_data$coordinates$lat, 4), 
                     round(integrated_data$coordinates$lon, 4), sep = "_"),
    pH = props$pH,
    OC = props$SOC,  # g/kg
    Olsen_P = props$Olsen_P,  # mg/kg
    Exch_K = props$Exch_K,  # mmol/kg
    Total_N = props$Total_N
  )
  
  # Add uncertainty information
  quefts_soil$uncertainty_info <- integrated_data$uncertainties
  quefts_soil$data_quality <- integrated_data$data_quality
  quefts_soil$uncertainty_tier <- integrated_data$uncertainty_tier
  
  return(quefts_soil)
}

#' Generate data quality summary
generate_data_summary <- function(integrated_data) {
  
  summary <- list(
    coordinates = integrated_data$coordinates,
    data_quality = integrated_data$data_quality,
    uncertainty_level = integrated_data$uncertainty_level,
    spatial_resolution = integrated_data$spatial_resolution,
    data_sources = integrated_data$data_sources,
    integration_date = integrated_data$integration_date
  )
  
  # Calculate overall uncertainty score (0-1, where 0 is perfect, 1 is highly uncertain)
  uncertainty_scores <- list(
    "very_low" = 0.1,
    "low" = 0.3,
    "medium" = 0.6,
    "high" = 0.9
  )
  
  summary$overall_uncertainty_score <- uncertainty_scores[[integrated_data$uncertainty_level]]
  
  # Recommendations for data improvement
  summary$improvement_recommendations <- generate_improvement_recommendations(integrated_data)
  
  return(summary)
}

#' Generate recommendations for improving data quality
generate_improvement_recommendations <- function(data) {
  
  recommendations <- c()
  
  if (data$uncertainty_tier == 1) {
    recommendations <- c(recommendations, 
      "Consider regional soil survey data for better accuracy",
      "Conduct visual soil assessment to reduce uncertainty",
      "Simple field tests (pH strips) would significantly improve recommendations"
    )
  }
  
  if (data$uncertainty_tier <= 2) {
    recommendations <- c(recommendations,
      "Field observations and farmer knowledge would reduce uncertainty",
      "Laboratory soil analysis would provide highest accuracy"
    )
  }
  
  if (data$uncertainty_tier <= 3) {
    recommendations <- c(recommendations,
      "Laboratory analysis of key parameters (pH, organic carbon, available P and K) recommended for precision recommendations"
    )
  }
  
  # Check for high uncertainty in specific parameters
  uncertainties <- data$uncertainties
  
  if (!is.null(uncertainties$Olsen_P) && uncertainties$Olsen_P > 5) {
    recommendations <- c(recommendations,
      "Phosphorus availability has high uncertainty - soil test recommended"
    )
  }
  
  if (!is.null(uncertainties$Exch_K) && uncertainties$Exch_K > 3) {
    recommendations <- c(recommendations,
      "Potassium availability has high uncertainty - soil test recommended"
    )
  }
  
  return(recommendations)
}

cat("✓ Spatial Data Integration Module loaded successfully\n")
cat("Main function: get_multiscale_soil_data(lat, lon, ...)\n")
cat("Supports 4-tier data integration: Global → Regional → Field → Laboratory\n\n")
