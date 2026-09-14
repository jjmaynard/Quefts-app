"use client";

import { useEffect, useRef } from "react";
import type * as L from "leaflet";
import "leaflet/dist/leaflet.css";

interface LocationMapProps {
  lat: number;
  lon: number;
  onChange: (lat: number, lon: number) => void;
}

// Plain Leaflet (not react-leaflet) driven via refs: this component is only
// ever mounted client-side (see the next/dynamic import with ssr:false in
// CalculatorForm.tsx, since Leaflet touches `window`/`document` at import
// time and would break server rendering otherwise).
export default function LocationMap({ lat, lon, onChange }: LocationMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markerRef = useRef<L.Marker | null>(null);
  const onChangeRef = useRef(onChange);
  useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  useEffect(() => {
    let cancelled = false;

    import("leaflet").then((L) => {
      if (cancelled || !containerRef.current || mapRef.current) return;

      // Default marker icon URLs break under bundlers unless re-pointed at
      // the package's own asset files (a well-known Leaflet/webpack issue).
      delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)
        ._getIconUrl;
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
        iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
        shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
      });

      const map = L.map(containerRef.current).setView([lat, lon], 6);
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors",
        maxZoom: 18,
      }).addTo(map);

      const marker = L.marker([lat, lon]).addTo(map);

      map.on("click", (e: L.LeafletMouseEvent) => {
        const { lat: clickLat, lng: clickLon } = e.latlng;
        marker.setLatLng([clickLat, clickLon]);
        onChangeRef.current(
          Math.round(clickLat * 10000) / 10000,
          Math.round(clickLon * 10000) / 10000,
        );
      });

      mapRef.current = map;
      markerRef.current = marker;
    });

    return () => {
      cancelled = true;
      mapRef.current?.remove();
      mapRef.current = null;
    };
    // Intentionally only runs once on mount; lat/lon changes from typing in
    // the form fields are synced separately below rather than re-creating
    // the map (which would reset pan/zoom on every keystroke).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Keep the marker/view in sync when lat/lon change from the numeric
  // inputs (not from a map click, which already updated them directly).
  useEffect(() => {
    if (mapRef.current && markerRef.current) {
      markerRef.current.setLatLng([lat, lon]);
      mapRef.current.panTo([lat, lon]);
    }
  }, [lat, lon]);

  return (
    <div
      ref={containerRef}
      className="h-56 w-full rounded-lg border border-black/15 dark:border-white/20"
    />
  );
}
