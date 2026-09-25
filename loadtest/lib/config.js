// Settings shared by all scenarios. Defaults are in defaults.json (also read by
// the report); every setting can be overridden with an environment variable of
// the same name (see loadtest/README.md). AREAS is a list of Norwegian towns,
// [lon, lat, spread in degrees], for the OSM Norway data.

const DEFAULTS = JSON.parse(open('./defaults.json'));

const env = (name) => (__ENV[name] !== undefined && __ENV[name] !== '' ? __ENV[name] : DEFAULTS[name]);
const list = (value) => value.split(',').map((s) => s.trim()).filter(Boolean);

export const BASE_URL = env('BASE_URL');
export const WORKSPACE = env('WORKSPACE');
export const SEED = Number(env('SEED'));
export const VUS = Number(env('VUS'));
export const DURATION = env('DURATION');
// Optional warm-up before the measured part of the run, e.g. "30s". Warm-up
// requests run in separate scenarios (suffix "_warmup") that the report ignores.
export const WARMUP = env('WARMUP');
// Seconds a simulated user waits between two map views.
export const THINK_MIN = Number(env('THINK_MIN'));
export const THINK_MAX = Number(env('THINK_MAX'));

// Layers requested as tiles, bottom to top, like a map's layer list.
export const TILE_LAYERS = list(env('TILE_LAYERS'));
// Tile format: "vector" (OGC API vector tiles) or "map" (OGC API map tiles, PNG).
export const TILE_FORMAT = env('TILE_FORMAT');
export const WMS_LAYERS = list(env('WMS_LAYERS'));
export const FEATURE_LAYERS = list(env('FEATURE_LAYERS'));

// Viewport in 256 px tiles: 6 x 4 is roughly a 1536 x 1024 browser map.
export const VIEW_COLS = Number(env('VIEW_COLS'));
export const VIEW_ROWS = Number(env('VIEW_ROWS'));

// Zoom levels a user looks at, as zoom:weight.
export const ZOOMS = list(env('ZOOMS')).map((s) => s.split(':').map(Number));
export const AREAS = JSON.parse(env('AREAS'));
export const COLD_CACHE = env('COLD_CACHE') === 'true';

export const ADMIN_USER = __ENV.GEOSERVER_ADMIN_USER || 'admin';
export const ADMIN_PASSWORD = __ENV.GEOSERVER_ADMIN_PASSWORD || '';
