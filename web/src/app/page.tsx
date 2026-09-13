"use client";

import { useEffect, useState } from "react";
import CalculatorForm from "@/components/CalculatorForm";
import ResultsView from "@/components/ResultsView";
import { ApiError, getCrops, getRecommendation } from "@/lib/api";
import type {
  CropsResponse,
  RecommendationRequest,
  RecommendationResponse,
} from "@/lib/types";

export default function Home() {
  const [crops, setCrops] = useState<CropsResponse>({});
  const [cropsError, setCropsError] = useState<string | null>(null);

  const [result, setResult] = useState<RecommendationResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getCrops()
      .then(setCrops)
      .catch((err: unknown) =>
        setCropsError(
          err instanceof ApiError || err instanceof Error
            ? err.message
            : "Unknown error",
        ),
      );
  }, []);

  async function handleSubmit(request: RecommendationRequest) {
    setLoading(true);
    setError(null);
    setResult(null);
    try {
      const response = await getRecommendation(request);
      setResult(response);
    } catch (err) {
      setError(
        err instanceof ApiError || err instanceof Error
          ? err.message
          : "Unknown error contacting the recommendation service.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex w-full max-w-5xl flex-1 flex-col gap-8 px-4 py-10 sm:px-6">
      <header>
        <h1 className="text-2xl font-bold sm:text-3xl">
          QUEFTS Fertilizer Decision Support
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-black/60 dark:text-white/60">
          Enter a field location, crop, and target yield to get a fertilizer
          recommendation with uncertainty quantification, agronomic insights,
          and (optionally) economic analysis, powered by the QUEFTS model
          (Janssen et al., 1990).
        </p>
      </header>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-[380px_1fr]">
        <CalculatorForm
          crops={crops}
          cropsError={cropsError}
          onSubmit={handleSubmit}
          loading={loading}
        />

        <div>
          {!result && !error && !loading && (
            <div className="flex h-full min-h-64 items-center justify-center rounded-xl border border-dashed border-black/15 p-8 text-center text-sm text-black/50 dark:border-white/15 dark:text-white/50">
              Fill in the form and click &ldquo;Get recommendation&rdquo; to
              see results here.
            </div>
          )}

          {loading && (
            <div className="flex h-full min-h-64 items-center justify-center rounded-xl border border-black/10 p-8 text-center text-sm text-black/60 dark:border-white/10 dark:text-white/60">
              Running Monte Carlo simulation... this can take a little while.
            </div>
          )}

          {error && (
            <div className="rounded-xl border border-red-300 bg-red-50 p-6 text-sm text-red-800 dark:border-red-800 dark:bg-red-950 dark:text-red-200">
              <p className="font-semibold">Could not get a recommendation</p>
              <p className="mt-1">{error}</p>
              <p className="mt-3 text-xs opacity-75">
                Is the API running? Start it with{" "}
                <code className="rounded bg-black/10 px-1 py-0.5 dark:bg-white/10">
                  Rscript api/run_api.R
                </code>{" "}
                from the project root.
              </p>
            </div>
          )}

          {result && <ResultsView result={result} />}
        </div>
      </div>
    </div>
  );
}
