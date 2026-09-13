# Converted from tests/test_integration.R. The original just checked that
# functions/objects existed (now covered by test-module-loading.R) and made
# one live call to get_multiscale_soil_data() against the real SoilGrids
# API -- flaky by design (PROJECT_EVALUATION.md Sec 6.3 already flags this;
# it returned a 500 during Phase 2/3 testing of this very session). This
# file instead runs the real, full comprehensive_fertilizer_recommendation()
# pipeline end-to-end against a mocked SoilGrids response, so the test is
# deterministic while still exercising every step (1-7) for real.

test_that("comprehensive_fertilizer_recommendation() runs end-to-end and returns a complete result", {
  # get_multiscale_soil_data() calls fetch_soilgrids_data() unqualified, so
  # the mock must live in globalenv() (where spatial_data_integration.R's
  # functions were sourced) for lexical scoping to pick it up -- assigning
  # inside this test_that() block's own environment would not be seen.
  original_fetch <- get("fetch_soilgrids_data", envir = globalenv())
  assign("fetch_soilgrids_data", fixture_mock_soilgrids_data, envir = globalenv())
  withr::defer(assign("fetch_soilgrids_data", original_fetch, envir = globalenv()))

  fertilizer_prices <- list(
    N_per_kg = 1.2, P_per_kg = 2.5, K_per_kg = 1.0, crop_price_per_kg = 0.3
  )

  result <- comprehensive_fertilizer_recommendation(
    lat = 7.5, lon = -1.5, crop_name = "Maize", target_yield = 6000,
    fertilizer_prices = fertilizer_prices,
    n_simulations = fixture_n_simulations
  )

  # Steps 1-5 (spatial data -> uncertainty -> probabilistic recs -> decision
  # -> sensitivity), unchanged since Phase 2.
  expect_equal(result$spatial_analysis$data_quality, "global_maps")
  expect_true(all(c("conf_50", "conf_80", "conf_95") %in% names(result$probabilistic_recommendations)))
  expect_true(result$decision_recommendation$recommendation %in%
                c("APPLY_FERTILIZER", "APPLY_FERTILIZER_CAUTIOUSLY", "DO_NOT_APPLY"))
  expect_false(is.null(result$sensitivity_analysis$most_sensitive))

  # Step 6 (Phase 3 wiring): report-ready output.
  expect_null(result$report_generation_note)
  expect_false(is.null(result$primary_recommendations))
  expect_false(is.null(result$agronomic_insights))
  expect_false(is.null(result$economic_analysis))
  expect_true(all(c("expert", "beginner", "intermediate") %in% names(result$user_reports)))
  expect_true(is.character(result$user_reports$beginner))
  expect_gt(nchar(result$user_reports$beginner), 0)
})

test_that("comprehensive_fertilizer_recommendation() still returns Steps 1-5 when fertilizer_prices is omitted", {
  original_fetch <- get("fetch_soilgrids_data", envir = globalenv())
  assign("fetch_soilgrids_data", fixture_mock_soilgrids_data, envir = globalenv())
  withr::defer(assign("fetch_soilgrids_data", original_fetch, envir = globalenv()))

  result <- comprehensive_fertilizer_recommendation(
    lat = 7.5, lon = -1.5, crop_name = "Maize", target_yield = 6000,
    n_simulations = fixture_n_simulations
  )

  expect_false(is.null(result$decision_recommendation))
  # No fertilizer_prices -> no economic analysis -> beginner/intermediate
  # reports are skipped (see Phase 3 notes in PROJECT_TRACKER.md), but the
  # expert report never needs economic_analysis so it should still exist.
  expect_null(result$economic_analysis)
  expect_true("expert" %in% names(result$user_reports))
  expect_false("beginner" %in% names(result$user_reports))
})
