const MAPBOX_STYLE = "mapbox/light-v11";

export const MAPBOX_ACCESS_TOKEN =
  process.env.NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN ?? ""; // يُمرَّر وقت البناء (docker-compose → MAPBOX_ACCESS_TOKEN)

export function mapboxTileUrl() {
  return `https://api.mapbox.com/styles/v1/${MAPBOX_STYLE}/tiles/{z}/{x}/{y}?access_token=${MAPBOX_ACCESS_TOKEN}`;
}

export const MAPBOX_ATTRIBUTION =
  '&copy; <a href="https://www.mapbox.com/">Mapbox</a> &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>';

export const MAPBOX_TILE_OPTIONS = {
  tileSize: 512,
  zoomOffset: -1,
  maxZoom: 20,
  attribution: MAPBOX_ATTRIBUTION,
} as const;
