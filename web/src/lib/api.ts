import type {
  ApiErrorResponse,
  CropsResponse,
  RecommendationRequest,
  RecommendationResponse,
} from "./types";

// The Plumber API's base URL (see api/run_api.R -- defaults to port 8000).
// Configure via .env.local for a non-default deployment; see .env.local.example.
const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") ?? "http://127.0.0.1:8000";

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function parseJsonOrThrow<T>(res: Response): Promise<T> {
  const text = await res.text();
  let body: unknown;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = null;
  }

  if (!res.ok) {
    const message =
      (body as ApiErrorResponse | null)?.error ??
      `Request failed with status ${res.status}`;
    throw new ApiError(message, res.status);
  }

  return body as T;
}

export async function getCrops(): Promise<CropsResponse> {
  const res = await fetch(`${API_BASE_URL}/crops`, { cache: "no-store" });
  return parseJsonOrThrow<CropsResponse>(res);
}

export async function getRecommendation(
  payload: RecommendationRequest,
): Promise<RecommendationResponse> {
  const res = await fetch(`${API_BASE_URL}/recommendation`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    cache: "no-store",
  });
  return parseJsonOrThrow<RecommendationResponse>(res);
}

/**
 * Fetch a previously computed, persisted result by its `result_id` (see
 * POST /recommendation's response) -- used by the server-rendered
 * /results/[id] page. NEXT_PUBLIC_API_URL is reused here even though this
 * runs server-side during SSR, since in local dev both the browser and the
 * Next.js server reach the API at the same address; a real deployment
 * (Phase 9) may want a separate server-only API URL instead.
 */
export async function getStoredRecommendation(
  id: string,
): Promise<RecommendationResponse> {
  const res = await fetch(`${API_BASE_URL}/recommendation/${encodeURIComponent(id)}`, {
    cache: "no-store",
  });
  return parseJsonOrThrow<RecommendationResponse>(res);
}
