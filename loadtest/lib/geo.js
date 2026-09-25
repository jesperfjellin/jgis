// Web Mercator tile maths and a seeded random number generator, so every run
// requests the same sequence of views and runs can be compared.

const R = 6378137;
const HALF = Math.PI * R;

export function lonLatToTile(lon, lat, z) {
  const n = 2 ** z;
  const x = Math.floor(((lon + 180) / 360) * n);
  const latRad = (lat * Math.PI) / 180;
  const y = Math.floor(((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2) * n);
  return { x: clamp(x, 0, n - 1), y: clamp(y, 0, n - 1) };
}

// Tile bounds in EPSG:3857, as "minx,miny,maxx,maxy".
export function tileBbox3857(z, x, y) {
  const size = (2 * HALF) / 2 ** z;
  const minx = -HALF + x * size;
  const maxy = HALF - y * size;
  return `${minx},${maxy - size},${minx + size},${maxy}`;
}

// Tile bounds in EPSG:4326 lon/lat, as [minLon, minLat, maxLon, maxLat].
export function tileBbox4326(z, x, y) {
  const n = 2 ** z;
  const lon = (tx) => (tx / n) * 360 - 180;
  const lat = (ty) => (Math.atan(Math.sinh(Math.PI * (1 - (2 * ty) / n))) * 180) / Math.PI;
  return [lon(x), lat(y + 1), lon(x + 1), lat(y)];
}

// The tiles covering a viewport of `cols` x `rows` tiles centred on a tile.
export function viewTiles(z, cx, cy, cols, rows) {
  const n = 2 ** z;
  const tiles = [];
  const x0 = cx - Math.floor(cols / 2);
  const y0 = cy - Math.floor(rows / 2);
  for (let y = y0; y < y0 + rows; y++) {
    for (let x = x0; x < x0 + cols; x++) {
      if (y >= 0 && y < n) tiles.push({ z, x: ((x % n) + n) % n, y });
    }
  }
  return tiles;
}

// mulberry32: small, fast, deterministic.
export function rng(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function pick(rand, items) {
  return items[Math.floor(rand() * items.length)];
}

// items: [[value, weight], ...]
export function weighted(rand, items) {
  const total = items.reduce((sum, [, w]) => sum + w, 0);
  let r = rand() * total;
  for (const [value, w] of items) {
    r -= w;
    if (r < 0) return value;
  }
  return items[items.length - 1][0];
}

function clamp(v, lo, hi) {
  return Math.min(hi, Math.max(lo, v));
}
