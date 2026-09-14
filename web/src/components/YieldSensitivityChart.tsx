"use client";

import { useState } from "react";
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import type { ParameterSensitivityCurve } from "@/lib/types";

interface YieldSensitivityChartProps {
  parameterSensitivities: Record<string, ParameterSensitivityCurve>;
  mostSensitive: string | null;
}

// A real yield-response curve: predicted yield as one soil parameter is
// perturbed +-20% or so around its measured value, holding everything else
// fixed (see perform_sensitivity_analysis() in uncertainty_quantification.R,
// and PROJECT_TRACKER.md Phase 8 for why this -- not a fertilizer-rate
// sweep, which the API doesn't compute -- is what's actually available to
// chart here).
export default function YieldSensitivityChart({
  parameterSensitivities,
  mostSensitive,
}: YieldSensitivityChartProps) {
  const parameters = Object.keys(parameterSensitivities);
  const [selected, setSelected] = useState(
    mostSensitive && parameters.includes(mostSensitive)
      ? mostSensitive
      : parameters[0],
  );

  if (parameters.length === 0) return null;

  const curve = parameterSensitivities[selected];
  const data = curve.parameter_values.map((value, i) => ({
    value,
    yield: curve.yield_responses[i],
  }));

  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <span className="text-xs text-black/50 dark:text-white/50">
          Predicted yield as this parameter varies, other factors held fixed
        </span>
        <select
          value={selected}
          onChange={(e) => setSelected(e.target.value)}
          className="rounded-md border border-black/15 bg-white px-2 py-1 text-xs dark:border-white/20 dark:bg-white/10"
        >
          {parameters.map((param) => (
            <option key={param} value={param}>
              {param}
            </option>
          ))}
        </select>
      </div>
      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" className="opacity-20" />
          <XAxis
            dataKey="value"
            tick={{ fontSize: 11 }}
            label={{ value: selected, position: "insideBottom", offset: -2, fontSize: 11 }}
          />
          <YAxis
            tick={{ fontSize: 11 }}
            width={60}
            label={{
              value: "Yield (kg/ha)",
              angle: -90,
              position: "insideLeft",
              fontSize: 11,
            }}
          />
          <Tooltip
            formatter={(v) => [`${Number(v).toFixed(0)} kg/ha`, "Predicted yield"]}
            labelFormatter={(v) => `${selected} = ${v}`}
          />
          <Line
            type="monotone"
            dataKey="yield"
            stroke="#059669"
            strokeWidth={2}
            dot={{ r: 3 }}
          />
        </LineChart>
      </ResponsiveContainer>
      <p className="mt-2 text-xs text-black/50 dark:text-white/50">
        Relative sensitivity: {(curve.relative_sensitivity * 100).toFixed(1)}%
      </p>
    </div>
  );
}
