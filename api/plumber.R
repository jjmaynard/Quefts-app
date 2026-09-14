# ================================================================================
# QUEFTS DECISION SUPPORT API
# Wraps comprehensive_fertilizer_recommendation() (R/decision_support/
# integrated_decision_support.R) and list_crop_parameters() (R/core/
# quefts_calculation_engine.R) as an HTTP API, per PROJECT_EVALUATION.md
# Sec 8.5 Phase A / PROJECT_TRACKER.md Phase 6.
#
# Run from the project root (required for the root-relative source() calls
# below to resolve, and for renv to activate):
#
#   Rscript api/run_api.R
#
# Then, e.g.:
#   curl http://127.0.0.1:8000/crops
#   curl -X POST http://127.0.0.1:8000/recommendation \
#        -H "Content-Type: application/json" \
#        -d '{"lat":7.5,"lon":-1.5,"crop_name":"Maize","target_yield":6000}'
# ================================================================================

# plumber::plumb() evaluates this file with the working directory set to
# api/ itself, not the project root -- so this can't be a plain
# root-relative source() call (see PROJECT_TRACKER.md Phase 6 for the
# discovery). api/run_api.R sets QUEFTS_PROJECT_ROOT before calling plumb();
# fall back to ".." for direct plumb("api/plumber.R") calls from the root.
.quefts_root <- Sys.getenv("QUEFTS_PROJECT_ROOT", unset = "..")
withr::with_dir(.quefts_root, {
  source("R/decision_support/integrated_decision_support.R")
})

# ================================================================================
# RESULT PERSISTENCE (Phase 8 -- shareable /results/[id] pages)
#
# Every POST /recommendation is saved to disk under a generated id, so the
# Next.js frontend can link to /results/<id>, which server-renders the same
# result via GET /recommendation/<id> without recomputing it. This is a
# simple flat-file store (one JSON file per result) -- fine for this
# skeleton; a real deployment would want a database with expiry (see
# PROJECT_TRACKER.md Phase 9).
# ================================================================================

.results_cache_dir <- file.path(.quefts_root, "api", ".cache", "results")
dir.create(.results_cache_dir, recursive = TRUE, showWarnings = FALSE)

.generate_result_id <- function() {
  timestamp <- gsub("[^0-9]", "", format(Sys.time(), "%Y%m%d%H%M%OS3"))
  paste0(timestamp, "-", sprintf("%04d", sample.int(9999, 1)))
}

.save_result <- function(id, response) {
  jsonlite::write_json(
    response, file.path(.results_cache_dir, paste0(id, ".json")),
    auto_unbox = TRUE, null = "null", pretty = FALSE
  )
}

.load_result <- function(id) {
  # Reject anything that isn't a bare id (defense against path traversal --
  # this id is taken directly from the URL path).
  if (!grepl("^[A-Za-z0-9._-]+$", id)) return(NULL)
  path <- file.path(.results_cache_dir, paste0(id, ".json"))
  if (!file.exists(path)) return(NULL)
  jsonlite::read_json(path, simplifyVector = TRUE)
}

#* @apiTitle QUEFTS Decision Support API
#* @apiDescription Fertilizer recommendations with uncertainty quantification,
#*   agronomic insights, and economic analysis, built on the QUEFTS model
#*   (Janssen et al., 1990). See PROJECT_EVALUATION.md and PROJECT_TRACKER.md
#*   in the project repository for the system's development history and
#*   known limitations.

#* @plumber
function(pr) {
  # Without auto_unbox, every scalar serializes as a length-1 JSON array
  # (e.g. "status":["ok"]) -- unbox them so single values come back as plain
  # JSON scalars. Also render R NULLs (e.g. an omitted optional field like
  # `region`, or report_generation_note on success) as JSON `null` rather
  # than jsonlite's default `{}`, which is what API consumers expect.
  plumber::pr_set_serializer(pr, plumber::serializer_unboxed_json(null = "null"))
}

# Allow cross-origin requests (the web/ Next.js dev server runs on a
# different origin/port than this API), and answer CORS preflight OPTIONS
# requests directly rather than routing them into the actual endpoints
# below (which don't handle OPTIONS). Fine for local development / this
# skeleton; a real deployment should restrict Access-Control-Allow-Origin
# to the deployed frontend's actual origin instead of "*" (see
# PROJECT_TRACKER.md Phase 9).
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  if (identical(req$REQUEST_METHOD, "OPTIONS")) {
    res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    res$setHeader("Access-Control-Allow-Headers", "Content-Type")
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

#* Health check
#* @get /health
function() {
  list(status = "ok", time = as.character(Sys.time()))
}

#* List available crops and their QUEFTS parameters
#*
#* Returns the same crop database get_crop_parameters() draws from, so
#* callers can discover valid `crop_name` values for POST /recommendation
#* instead of having them hardcoded independently.
#* @get /crops
function() {
  list_crop_parameters()
}

#* Generate a fertilizer recommendation with uncertainty analysis
#*
#* Runs the full comprehensive_fertilizer_recommendation() pipeline: spatial
#* soil data integration (SoilGrids, refined by any field_observations/
#* lab_results supplied), Monte Carlo uncertainty propagation, a risk-based
#* decision, sensitivity analysis, and (Phase 3) report-ready output --
#* primary recommendations, agronomic insights, economic analysis (if
#* fertilizer_prices is supplied), and beginner/intermediate/expert text
#* reports. The response omits raw Monte Carlo sample arrays and the full
#* spatial data payload to keep it a reasonable size; see
#* R/decision_support/integrated_decision_support.R if you need those.
#*
#* @param lat:numeric Latitude of the field.
#* @param lon:numeric Longitude of the field.
#* @param crop_name:character Crop name -- see GET /crops for valid values.
#* @param target_yield:numeric Target yield, kg/ha.
#* @param region Optional region code for regional calibration (e.g. "Sub-Saharan_Africa").
#* @param field_observations Optional list of field-level soil observations.
#* @param lab_results Optional list of laboratory soil analysis results.
#* @param fertilizer_prices Optional list with N_per_kg, P_per_kg, K_per_kg,
#*   crop_price_per_kg (USD) -- enables economic analysis and the
#*   beginner/intermediate reports; omit for an agronomic-only recommendation.
#* @param risk_tolerance:character One of "conservative", "moderate" (default), "aggressive".
#* @param n_simulations:numeric Monte Carlo iterations (default 200 -- lower
#*   than the 1000 used elsewhere in this project, traded off here for
#*   request latency; raise it for a less noisy result if you can wait longer).
#* @post /recommendation
function(res, lat = NULL, lon = NULL, crop_name = NULL, target_yield = NULL,
         region = NULL, field_observations = NULL, lab_results = NULL,
         fertilizer_prices = NULL, risk_tolerance = "moderate",
         n_simulations = 200) {

  # lat/lon/crop_name/target_yield default to NULL (rather than being
  # required arguments) specifically so a request that omits one gets this
  # 400 response -- with required arguments instead, plumber would call this
  # function with an argument missing and R's "argument is missing, with no
  # default" error would surface as an opaque 500.
  if (is.null(lat) || is.null(lon) || is.null(crop_name) || is.null(target_yield)) {
    res$status <- 400
    return(list(error = "lat, lon, crop_name and target_yield are all required."))
  }

  lat <- as.numeric(lat)
  lon <- as.numeric(lon)
  target_yield <- as.numeric(target_yield)
  n_simulations <- as.numeric(n_simulations)

  if (any(is.na(c(lat, lon, target_yield, n_simulations))) || !nzchar(crop_name)) {
    res$status <- 400
    return(list(error = "lat, lon, target_yield and crop_name are required, and lat/lon/target_yield/n_simulations must be numeric."))
  }

  result <- tryCatch({
    comprehensive_fertilizer_recommendation(
      lat = lat, lon = lon, crop_name = crop_name, target_yield = target_yield,
      region = region, field_observations = field_observations, lab_results = lab_results,
      fertilizer_prices = fertilizer_prices, risk_tolerance = risk_tolerance,
      n_simulations = n_simulations
    )
  }, error = function(e) {
    list(.api_error = conditionMessage(e))
  })

  if (!is.null(result$.api_error)) {
    res$status <- 502
    return(list(error = result$.api_error))
  }

  # Trim large/redundant fields (raw Monte Carlo sample vectors, the full
  # spatial data payload) before returning -- see the endpoint description.
  result$primary_recommendations$yield_predictions$probability_distributions$samples <- NULL
  result$economic_analysis$risk_metrics$profit_distribution$samples <- NULL

  # parameter_sensitivities$<param>$parameter_values/yield_responses is a
  # real (if small -- 3-6 points) yield-response curve: predicted yield as
  # one soil parameter is perturbed +-. Included (unlike Phase 6's original
  # trimming) so the frontend can chart it -- see PROJECT_TRACKER.md Phase 8.
  sensitivity_curves <- lapply(
    result$sensitivity_analysis$parameter_sensitivities,
    function(p) list(
      parameter_values = p$parameter_values,
      yield_responses = p$yield_responses,
      relative_sensitivity = p$relative_sensitivity
    )
  )

  response <- list(
    result_id = .generate_result_id(),
    computed_at = as.character(Sys.time()),
    input_parameters = result$input_parameters,
    spatial_analysis = result$spatial_analysis,
    uncertainty_summary = list(
      success_probability = result$uncertainty_analysis$success_probability,
      risk_assessment = result$uncertainty_analysis$risk_assessment
    ),
    probabilistic_recommendations = result$probabilistic_recommendations,
    decision_recommendation = result$decision_recommendation,
    sensitivity_analysis = list(
      most_sensitive = result$sensitivity_analysis$most_sensitive,
      least_sensitive = result$sensitivity_analysis$least_sensitive,
      sensitivity_ranking = result$sensitivity_analysis$sensitivity_ranking,
      parameter_sensitivities = sensitivity_curves
    ),
    primary_recommendations = result$primary_recommendations,
    agronomic_insights = result$agronomic_insights,
    economic_analysis = result$economic_analysis,
    user_reports = result$user_reports,
    report_generation_note = result$report_generation_note
  )

  .save_result(response$result_id, response)

  response
}

#* Retrieve a previously computed recommendation by id
#*
#* Backs the Next.js frontend's shareable /results/[id] pages: a result
#* computed via POST /recommendation is saved under its `result_id`, and
#* this endpoint serves it back without recomputing anything.
#* @get /recommendation/<id>
function(res, id) {
  stored <- .load_result(id)
  if (is.null(stored)) {
    res$status <- 404
    return(list(error = paste0("No stored result with id '", id, "'.")))
  }
  stored
}
