"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ErrorBar,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

interface ValueWithCI {
  median: number;
  lower_ci: number;
  upper_ci: number;
}

interface UncertaintyBandsChartProps {
  fertilizerRates: { N: ValueWithCI; P: ValueWithCI; K: ValueWithCI };
  confidenceLevel: number;
}

export default function UncertaintyBandsChart({
  fertilizerRates,
  confidenceLevel,
}: UncertaintyBandsChartProps) {
  const data = (["N", "P", "K"] as const).map((nutrient) => {
    const rate = fertilizerRates[nutrient];
    return {
      nutrient,
      median: rate.median,
      // recharts' ErrorBar dataKey resolves to [negative offset, positive
      // offset] added around the bar's own value, not absolute bounds.
      errorRange: [rate.median - rate.lower_ci, rate.upper_ci - rate.median],
    };
  });

  return (
    <div>
      <p className="mb-3 text-xs text-black/50 dark:text-white/50">
        Median recommended rate with {(confidenceLevel * 100).toFixed(0)}%
        confidence interval
      </p>
      <ResponsiveContainer width="100%" height={220}>
        <BarChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" className="opacity-20" />
          <XAxis dataKey="nutrient" tick={{ fontSize: 12 }} />
          <YAxis
            tick={{ fontSize: 11 }}
            width={60}
            label={{
              value: "kg/ha",
              angle: -90,
              position: "insideLeft",
              fontSize: 11,
            }}
          />
          <Tooltip
            formatter={(v) => `${Number(v).toFixed(1)} kg/ha`}
          />
          <Bar dataKey="median" fill="#059669" radius={[4, 4, 0, 0]}>
            <ErrorBar
              dataKey="errorRange"
              width={6}
              strokeWidth={2}
              stroke="#065f46"
            />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
