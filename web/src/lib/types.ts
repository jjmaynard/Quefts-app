// Types mirror the curated JSON shape api/plumber.R's POST /recommendation
// and GET /crops endpoints return (see PROJECT_TRACKER.md Phase 6). Fields
// the UI doesn't render are typed loosely (Record<string, unknown>) rather
// than exhaustively, since the R backend's result objects are deeply nested
// and only partially stable -- see PROJECT_TRACKER.md Phases 3-5 for the
// field-naming inconsistencies already found in the R layer itself.

export interface CropParameters {
  yield_potential: number;
  N_requirement_per_ton: number;
  P_requirement_per_ton: number;
  K_requirement_per_ton: number;
  harvest_index: number;
  growing_season: number;
}

export type CropsResponse = Record<string, CropParameters>;

export interface FertilizerPrices {
  N_per_kg: number;
  P_per_kg: number;
  K_per_kg: number;
  crop_price_per_kg: number;
}

export interface RecommendationRequest {
  lat: number;
  lon: number;
  crop_name: string;
  target_yield: number;
  region?: string;
  risk_tolerance?: "conservative" | "moderate" | "aggressive";
  fertilizer_prices?: FertilizerPrices;
  n_simulations?: number;
}

interface ValueWithCI {
  median: number;
  lower_ci: number;
  upper_ci: number;
}

interface ProbabilisticTier {
  confidence_level: number;
  fertilizer_rates: { N: ValueWithCI; P: ValueWithCI; K: ValueWithCI };
  expected_yield: ValueWithCI;
  economic_return?: ValueWithCI;
}

export interface DecisionRecommendation {
  recommendation: string;
  confidence: string;
  rationale?: string[];
  economic_justification?: Record<string, unknown>;
  agronomic_justification?: Record<string, unknown>;
}

export interface RiskAssessment {
  fertilizer_uncertainty?: { overall_cv: number };
  yield_risk?: { cv: number; prob_target_achievement: number };
  economic_risk?: { prob_loss: number; expected_loss: number; var_95: number };
  overall_risk_score: number;
  risk_category: string;
}

export interface EconomicAnalysis {
  cost_benefit_analysis?: {
    costs?: { total_fertilizer_cost: number; total_cost_per_ha: number };
    revenue?: { additional_revenue: number };
    profitability?: { net_benefit: number; benefit_cost_ratio: number };
  };
  risk_metrics?: {
    probability_of_economic_loss: number;
    value_at_risk_95?: number;
  };
  decision_recommendation?: { decision: string; rationale: string };
}

export interface AgronomicInsights {
  nutrient_limitations?: {
    primary_limiting_nutrient: string;
    nutrient_supply_levels?: Record<
      string,
      { supply: number; status: string }
    >;
  };
  soil_health_indicators?: {
    overall_soil_health?: { health_status: string; overall_score: number };
  };
  environmental_assessment?: { overall_environmental_risk: string };
}

export interface UserReports {
  expert?: string;
  beginner?: string;
  intermediate?: string;
}

export interface RecommendationResponse {
  input_parameters: {
    location: { lat: number; lon: number };
    crop: string;
    target_yield: number;
    region: string | null;
    risk_tolerance: string;
    analysis_date: string;
  };
  spatial_analysis: {
    data_quality: string;
    uncertainty_tier: number;
    spatial_resolution: string;
    soil_properties: Record<string, number>;
    improvement_recommendations?: string[];
  };
  uncertainty_summary: {
    success_probability: number;
    risk_assessment: RiskAssessment;
  };
  probabilistic_recommendations: {
    conf_50: ProbabilisticTier;
    conf_80: ProbabilisticTier;
    conf_95: ProbabilisticTier;
  };
  decision_recommendation: DecisionRecommendation;
  sensitivity_analysis: {
    most_sensitive: string | null;
    least_sensitive: string | null;
    sensitivity_ranking: string[] | null;
    parameter_sensitivities?: Record<string, ParameterSensitivityCurve>;
  };
  primary_recommendations: Record<string, unknown> | null;
  agronomic_insights: AgronomicInsights | null;
  economic_analysis: EconomicAnalysis | null;
  user_reports: UserReports | null;
  report_generation_note: string | null;
  /** Present on POST /recommendation responses; used to build the
   * shareable /results/[id] link. Also present when a stored result is
   * re-fetched via GET /recommendation/:id. */
  result_id?: string;
  computed_at?: string;
}

/** A yield-response curve for one soil parameter: predicted yield as that
 * parameter is perturbed +-, holding the others fixed (see
 * perform_sensitivity_analysis() in uncertainty_quantification.R). */
export interface ParameterSensitivityCurve {
  parameter_values: number[];
  yield_responses: number[];
  relative_sensitivity: number;
}

export interface ApiErrorResponse {
  error: string;
}
