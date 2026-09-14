import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import ResultsView from "@/components/ResultsView";
import { ApiError, getStoredRecommendation } from "@/lib/api";

interface ResultsPageProps {
  params: Promise<{ id: string }>;
}

async function loadResult(id: string) {
  try {
    return await getStoredRecommendation(id);
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      return null;
    }
    throw err;
  }
}

export async function generateMetadata({
  params,
}: ResultsPageProps): Promise<Metadata> {
  const { id } = await params;
  const result = await loadResult(id);

  if (!result) {
    // Note: this branch's metadata is actually unreachable in practice --
    // the page component below calls notFound(), which renders Next's
    // not-found boundary (and its own default metadata) rather than using
    // whatever generateMetadata returned here. Left in for clarity /
    // in case that ever becomes a custom not-found.tsx with real metadata.
    return { title: "Result not found — QUEFTS Decision Support" };
  }

  const { crop, location } = result.input_parameters;
  const title = `${crop} fertilizer recommendation at ${location.lat}, ${location.lon}`;
  const description = `${result.decision_recommendation.recommendation.replace(
    /_/g,
    " ",
  )} · ${result.decision_recommendation.confidence} confidence — QUEFTS Decision Support`;

  return {
    title,
    description,
    openGraph: { title, description, type: "article" },
    twitter: { card: "summary", title, description },
  };
}

export default async function ResultsPage({ params }: ResultsPageProps) {
  const { id } = await params;
  const result = await loadResult(id);

  if (!result) {
    notFound();
  }

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 px-4 py-10 sm:px-6">
      <div className="flex items-center justify-between">
        <Link
          href="/"
          className="text-sm text-black/60 hover:underline dark:text-white/60"
        >
          ← New calculation
        </Link>
        {result.computed_at && (
          <span className="text-xs text-black/40 dark:text-white/40">
            Computed {new Date(result.computed_at).toLocaleString()}
          </span>
        )}
      </div>

      <header>
        <h1 className="text-xl font-bold sm:text-2xl">
          {result.input_parameters.crop} recommendation at{" "}
          {result.input_parameters.location.lat},{" "}
          {result.input_parameters.location.lon}
        </h1>
      </header>

      <ResultsView result={result} />
    </div>
  );
}
