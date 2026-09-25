// Settings shared by all scenarios. Everything can be overridden with
// environment variables (see loadtest/README.md).

const env = (name, fallback) => (__ENV[name] !== undefined && __ENV[name] !== '' ? __ENV[name] : fallback);
const list = (value) => value.split(',').map((s) => s.trim()).filter(Boolean);

export const BASE_URL = env('BASE_URL', 'http://geoserver:8080/geoserver');
export const WORKSPACE = env('WORKSPACE', 'osm');
export const SEED = Number(env('SEED', '1'));
export const VUS = Number(env('VUS', '10'));
export const DURATION = env('DURATION', '2m');
// Seconds a simulated user waits between two map views.
export const THINK_MIN = Number(env('THINK_MIN', '1'));
export const THINK_MAX = Number(env('THINK_MAX', '3'));

// Layers requested as tiles, bottom to top, like a map's layer list.
export const TILE_LAYERS = list(env('TILE_LAYERS', 'landcover,water,waterways,roads,railways,buildings'));
// Tile format: "vector" (OGC API vector tiles) or "map" (OGC API map tiles, PNG).
export const TILE_FORMAT = env('TILE_FORMAT', 'vector');
export const WMS_LAYERS = list(env('WMS_LAYERS', 'landcover,water,roads,buildings,places'));
export const FEATURE_LAYERS = list(env('FEATURE_LAYERS', 'places,pois,railways'));

// Viewport in 256 px tiles: 6 x 4 is roughly a 1536 x 1024 browser map.
export const VIEW_COLS = Number(env('VIEW_COLS', '6'));
export const VIEW_ROWS = Number(env('VIEW_ROWS', '4'));

// Zoom levels a user looks at, with relative weights.
export const ZOOMS = list(env('ZOOMS', '8:1,10:2,12:3,13:3,14:4,15:3,16:2')).map((s) => s.split(':').map(Number));

// Where users look: [lon, lat, spread in degrees]. Defaults are Norwegian towns
// of different sizes, for the OSM Norway data.
export const AREAS = JSON.parse(
  env(
    'AREAS',
    JSON.stringify([
      [10.75, 59.91, 0.25], // Oslo
      [5.33, 60.39, 0.2], // Bergen
      [10.4, 63.43, 0.15], // Trondheim
      [5.73, 58.97, 0.15], // Stavanger
      [8.0, 58.15, 0.1], // Kristiansand
      [18.96, 69.65, 0.1], // Tromsø
      [10.2, 59.74, 0.1], // Drammen
      [6.15, 62.47, 0.1], // Ålesund
      [10.47, 61.12, 0.1], // Lillehammer
      [14.4, 67.28, 0.1], // Bodø
    ]),
  ),
);

export const ADMIN_USER = env('GEOSERVER_ADMIN_USER', 'admin');
export const ADMIN_PASSWORD = env('GEOSERVER_ADMIN_PASSWORD', '');
