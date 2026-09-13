"use client";

import { useState } from "react";
import type { RecommendationResponse } from "@/lib/types";

const decisionStyles: Record<string, string> = {
  APPLY_FERTILIZER:
    "bg-emerald-50 text-emerald-800 border-emerald-300 dark:bg-emerald-950 dark:text-emerald-200 dark:border-emerald-800",
  APPLY_FERTILIZER_CAUTIOUSLY:
    "bg-amber-50 text-amber-800 border-amber-300 dark:bg-amber-950 dark:text-amber-200 dark:border-amber-800",
  DO_NOT_APPLY:
    "bg-red-50 text-red-800 border-red-300 dark:bg-red-950 dark:text-red-200 dark:border-red-800",
  COLLECT_MORE_DATA:
    "bg-blue-50 text-blue-800 border-blue-300 dark:bg-blue-950 dark:text-blue-200 dark:border-blue-800",
};

function formatDecision(decision: string): string {
  return decision.replace(/_/g, " ");
}

function Stat({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-xs uppercase tracking-wide text-black/50 dark:text-white/50">
        {label}
      </span>
      <span className="text-lg font-semibold">{value}</span>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-white/5">
      <h3 className="mb-4 text-sm font-semibold uppercase tracking-wide text-black/60 dark:text-white/60">
        {title}
      </h3>
      {children}
    </section>
  );
}

export default function ResultsView({
  result,
}: {
  result: RecommendationResponse;
}) {
  const [activeReport, setActiveReport] = useState<
    "expert" | "beginner" | "intermediate" | null
  >(null);

  const conf80 = result.probabilistic_recommendations?.conf_80;
  const decision = result.decision_recommendation;
  const risk = result.uncertainty_summary?.risk_assessment;
  const econ = result.economic_analysis;
  const agronomic = result.agronomic_insights;
  const reports = result.user_reports;

  const availableReports = (
    ["expert", "beginner", "intermediate"] as const
  ).filter((level) => reports?.[level]);

  return (
    <div className="flex flex-col gap-6">
      {result.report_generation_note && (
        <div className="rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-800 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-200">
          {result.report_generation_note}
        </div>
      )}

      <div
        className={`rounded-xl border p-6 ${
          decisionStyles[decision.recommendation] ??
          "border-black/10 bg-black/5 dark:border-white/10 dark:bg-white/5"
        }`}
      >
        <p className="text-xs font-medium uppercase tracking-wide opacity-70">
          Decision · {decision.confidence} confidence
        </p>
        <p className="mt-1 text-2xl font-bold">
          {formatDecision(decision.recommendation)}
        </p>
        {decision.rationale && decision.rationale.length > 0 && (
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm opacity-90">
            {decision.rationale.map((reason, i) => (
              <li key={i}>{reason}</li>
            ))}
          </ul>
        )}
      </div>

      {conf80 && (
        <Section title="Fertilizer recommendation (80% confidence interval)">
          <div className="grid grid-cols-3 gap-6">
            <Stat
              label="Nitrogen (N)"
              value={`${conf80.fertilizer_rates.N.median.toFixed(0)} kg/ha`}
            />
            <Stat
              label="Phosphorus (P)"
              value={`${conf80.fertilizer_rates.P.median.toFixed(0)} kg/ha`}
            />
            <Stat
              label="Potassium (K)"
              value={`${conf80.fertilizer_rates.K.median.toFixed(0)} kg/ha`}
            />
          </div>
          <div className="mt-4 grid grid-cols-3 gap-6 text-xs text-black/50 dark:text-white/50">
            <span>
              [{conf80.fertilizer_rates.N.lower_ci.toFixed(0)} –{" "}
              {conf80.fertilizer_rates.N.upper_ci.toFixed(0)}]
            </span>
            <span>
              [{conf80.fertilizer_rates.P.lower_ci.toFixed(0)} –{" "}
              {conf80.fertilizer_rates.P.upper_ci.toFixed(0)}]
            </span>
            <span>
              [{conf80.fertilizer_rates.K.lower_ci.toFixed(0)} –{" "}
              {conf80.fertilizer_rates.K.upper_ci.toFixed(0)}]
            </span>
          </div>
          <div className="mt-6 border-t border-black/10 pt-4 dark:border-white/10">
            <Stat
              label="Expected yield"
              value={`${conf80.expected_yield.median.toFixed(0)} kg/ha [${conf80.expected_yield.lower_ci.toFixed(
                0,
              )} – ${conf80.expected_yield.upper_ci.toFixed(0)}]`}
            />
          </div>
        </Section>
      )}

      <Section title="Risk & uncertainty">
        <div className="grid grid-cols-2 gap-6 sm:grid-cols-3">
          <Stat
            label="Success probability"
            value={`${(result.uncertainty_summary.success_probability * 100).toFixed(0)}%`}
          />
          {risk && (
            <>
              <Stat label="Risk category" value={risk.risk_category} />
              <Stat
                label="Overall risk score"
                value={risk.overall_risk_score.toFixed(2)}
              />
            </>
          )}
          {result.sensitivity_analysis.most_sensitive && (
            <Stat
              label="Most sensitive parameter"
              value={result.sensitivity_analysis.most_sensitive}
            />
          )}
        </div>
      </Section>

      {econ?.cost_benefit_analysis && (
        <Section title="Economic analysis">
          <div className="grid grid-cols-2 gap-6 sm:grid-cols-3">
            {econ.cost_benefit_analysis.profitability && (
              <>
                <Stat
                  label="Net benefit"
                  value={`$${econ.cost_benefit_analysis.profitability.net_benefit.toFixed(2)}/ha`}
                />
                <Stat
                  label="Benefit:cost ratio"
                  value={econ.cost_benefit_analysis.profitability.benefit_cost_ratio.toFixed(
                    2,
                  )}
                />
              </>
            )}
            {econ.risk_metrics && (
              <Stat
                label="Probability of loss"
                value={`${(econ.risk_metrics.probability_of_economic_loss * 100).toFixed(0)}%`}
              />
            )}
          </div>
        </Section>
      )}

      {agronomic?.nutrient_limitations && (
        <Section title="Agronomic insights">
          <div className="grid grid-cols-2 gap-6 sm:grid-cols-3">
            <Stat
              label="Primary limiting nutrient"
              value={agronomic.nutrient_limitations.primary_limiting_nutrient}
            />
            {agronomic.soil_health_indicators?.overall_soil_health && (
              <Stat
                label="Soil health"
                value={
                  agronomic.soil_health_indicators.overall_soil_health
                    .health_status
                }
              />
            )}
            {agronomic.environmental_assessment && (
              <Stat
                label="Environmental risk"
                value={agronomic.environmental_assessment.overall_environmental_risk}
              />
            )}
          </div>
        </Section>
      )}

      {availableReports.length > 0 && (
        <Section title="Detailed reports">
          <div className="mb-4 flex gap-2">
            {availableReports.map((level) => (
              <button
                key={level}
                onClick={() =>
                  setActiveReport(activeReport === level ? null : level)
                }
                className={`rounded-md px-3 py-1.5 text-sm font-medium capitalize transition ${
                  activeReport === level
                    ? "bg-emerald-600 text-white"
                    : "bg-black/5 hover:bg-black/10 dark:bg-white/10 dark:hover:bg-white/20"
                }`}
              >
                {level}
              </button>
            ))}
          </div>
          {activeReport && reports?.[activeReport] && (
            <pre className="max-h-96 overflow-auto whitespace-pre-wrap rounded-lg bg-black/5 p-4 text-xs leading-relaxed dark:bg-white/10">
              {reports[activeReport]}
            </pre>
          )}
        </Section>
      )}
    </div>
  );
}
