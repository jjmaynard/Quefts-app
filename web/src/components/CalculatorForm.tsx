"use client";

import { useState } from "react";
import type { CropsResponse, RecommendationRequest } from "@/lib/types";

interface CalculatorFormProps {
  crops: CropsResponse;
  cropsError: string | null;
  onSubmit: (request: RecommendationRequest) => void;
  loading: boolean;
}

const cropNames = (crops: CropsResponse) => Object.keys(crops).sort();

export default function CalculatorForm({
  crops,
  cropsError,
  onSubmit,
  loading,
}: CalculatorFormProps) {
  const [lat, setLat] = useState("7.5");
  const [lon, setLon] = useState("-1.5");
  const [cropName, setCropName] = useState("Maize");
  const [targetYield, setTargetYield] = useState("6000");
  const [riskTolerance, setRiskTolerance] = useState<
    "conservative" | "moderate" | "aggressive"
  >("moderate");
  const [region, setRegion] = useState("Sub-Saharan_Africa");

  const [showPrices, setShowPrices] = useState(false);
  const [nPrice, setNPrice] = useState("1.2");
  const [pPrice, setPPrice] = useState("2.5");
  const [kPrice, setKPrice] = useState("1.0");
  const [cropPrice, setCropPrice] = useState("0.3");

  const availableCrops = cropNames(crops);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    const request: RecommendationRequest = {
      lat: parseFloat(lat),
      lon: parseFloat(lon),
      crop_name: cropName,
      target_yield: parseFloat(targetYield),
      risk_tolerance: riskTolerance,
      region: region.trim() || undefined,
    };

    if (showPrices) {
      request.fertilizer_prices = {
        N_per_kg: parseFloat(nPrice),
        P_per_kg: parseFloat(pPrice),
        K_per_kg: parseFloat(kPrice),
        crop_price_per_kg: parseFloat(cropPrice),
      };
    }

    onSubmit(request);
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-5 rounded-xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-white/5"
    >
      <div className="grid grid-cols-2 gap-4">
        <Field label="Latitude">
          <input
            type="number"
            step="any"
            required
            value={lat}
            onChange={(e) => setLat(e.target.value)}
            className={inputClass}
          />
        </Field>
        <Field label="Longitude">
          <input
            type="number"
            step="any"
            required
            value={lon}
            onChange={(e) => setLon(e.target.value)}
            className={inputClass}
          />
        </Field>
      </div>

      <Field label="Crop">
        {cropsError ? (
          <p className="text-sm text-red-600 dark:text-red-400">
            Could not load crop list: {cropsError}
          </p>
        ) : (
          <select
            value={cropName}
            onChange={(e) => setCropName(e.target.value)}
            className={inputClass}
            disabled={availableCrops.length === 0}
          >
            {availableCrops.length === 0 && <option>Loading...</option>}
            {availableCrops.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        )}
      </Field>

      <Field label="Target yield (kg/ha)">
        <input
          type="number"
          step="any"
          min="0"
          required
          value={targetYield}
          onChange={(e) => setTargetYield(e.target.value)}
          className={inputClass}
        />
      </Field>

      <Field label="Risk tolerance">
        <select
          value={riskTolerance}
          onChange={(e) =>
            setRiskTolerance(
              e.target.value as "conservative" | "moderate" | "aggressive",
            )
          }
          className={inputClass}
        >
          <option value="conservative">Conservative</option>
          <option value="moderate">Moderate</option>
          <option value="aggressive">Aggressive</option>
        </select>
      </Field>

      <Field label="Region (optional, for regional calibration)">
        <input
          type="text"
          value={region}
          onChange={(e) => setRegion(e.target.value)}
          placeholder="e.g. Sub-Saharan_Africa"
          className={inputClass}
        />
      </Field>

      <div className="border-t border-black/10 pt-4 dark:border-white/10">
        <label className="flex items-center gap-2 text-sm font-medium">
          <input
            type="checkbox"
            checked={showPrices}
            onChange={(e) => setShowPrices(e.target.checked)}
            className="h-4 w-4"
          />
          Include fertilizer &amp; crop prices (enables economic analysis)
        </label>

        {showPrices && (
          <div className="mt-4 grid grid-cols-2 gap-4">
            <Field label="N price (USD/kg)">
              <input
                type="number"
                step="any"
                min="0"
                value={nPrice}
                onChange={(e) => setNPrice(e.target.value)}
                className={inputClass}
              />
            </Field>
            <Field label="P price (USD/kg)">
              <input
                type="number"
                step="any"
                min="0"
                value={pPrice}
                onChange={(e) => setPPrice(e.target.value)}
                className={inputClass}
              />
            </Field>
            <Field label="K price (USD/kg)">
              <input
                type="number"
                step="any"
                min="0"
                value={kPrice}
                onChange={(e) => setKPrice(e.target.value)}
                className={inputClass}
              />
            </Field>
            <Field label="Crop price (USD/kg)">
              <input
                type="number"
                step="any"
                min="0"
                value={cropPrice}
                onChange={(e) => setCropPrice(e.target.value)}
                className={inputClass}
              />
            </Field>
          </div>
        )}
      </div>

      <button
        type="submit"
        disabled={loading}
        className="mt-2 rounded-lg bg-emerald-600 px-4 py-2.5 font-medium text-white transition hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {loading ? "Calculating..." : "Get recommendation"}
      </button>
    </form>
  );
}

const inputClass =
  "w-full rounded-md border border-black/15 bg-white px-3 py-2 text-sm outline-none focus:border-emerald-600 focus:ring-1 focus:ring-emerald-600 dark:border-white/20 dark:bg-white/10";

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="flex flex-col gap-1.5 text-sm font-medium">
      {label}
      {children}
    </label>
  );
}
