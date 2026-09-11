"use client";

import { useEffect, useRef } from "react";
import type { Map as LeafletMap, Marker as LeafletMarker } from "leaflet";
import "leaflet/dist/leaflet.css";

type MapProperty = {
  id: string;
  name: string;
  lat: number;
  lng: number;
  status: string;
};

export function PropertiesMap({
  properties,
  selectedId,
  onSelect,
}: {
  properties: MapProperty[];
  selectedId?: string | null;
  onSelect?: (id: string) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const markersRef = useRef<Map<string, LeafletMarker>>(new Map());

  useEffect(() => {
    let cancelled = false;

    async function init() {
      const L = await import("leaflet");
      if (cancelled || !containerRef.current || mapRef.current) return;

      const center = properties[0]
        ? [properties[0].lat, properties[0].lng] as [number, number]
        : ([33.3152, 44.3661] as [number, number]);

      const map = L.map(containerRef.current, { center, zoom: properties.length ? 7 : 6 });
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap",
        maxZoom: 19,
      }).addTo(map);

      mapRef.current = map;
    }

    void init();

    return () => {
      cancelled = true;
      mapRef.current?.remove();
      mapRef.current = null;
      markersRef.current.clear();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!mapRef.current) return;

    async function syncMarkers() {
      const L = await import("leaflet");
      const map = mapRef.current!;
      const icon = L.icon({
        iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
        iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
        shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
        iconSize: [25, 41],
        iconAnchor: [12, 41],
      });

      const nextIds = new Set(properties.map((p) => p.id));

      for (const [id, marker] of markersRef.current.entries()) {
        if (!nextIds.has(id)) {
          marker.remove();
          markersRef.current.delete(id);
        }
      }

      for (const p of properties) {
        if (Number.isNaN(p.lat) || Number.isNaN(p.lng)) continue;
        const existing = markersRef.current.get(p.id);
        if (existing) {
          existing.setLatLng([p.lat, p.lng]);
        } else {
          const marker = L.marker([p.lat, p.lng], { icon }).addTo(map);
          marker.bindPopup(`<strong>${p.name}</strong>`);
          marker.on("click", () => onSelect?.(p.id));
          markersRef.current.set(p.id, marker);
        }
      }

      if (properties.length) {
        const bounds = L.latLngBounds(properties.map((p) => [p.lat, p.lng] as [number, number]));
        map.fitBounds(bounds, { padding: [40, 40], maxZoom: 12 });
      }
    }

    void syncMarkers();
  }, [properties, onSelect]);

  useEffect(() => {
    if (!selectedId) return;
    const marker = markersRef.current.get(selectedId);
    const map = mapRef.current;
    if (marker && map) {
      map.setView(marker.getLatLng(), Math.max(map.getZoom(), 12), { animate: true });
      marker.openPopup();
    }
  }, [selectedId]);

  return (
    <div
      ref={containerRef}
      className="map-frame"
      style={{ height: "480px", zIndex: 0 }}
    />
  );
}
