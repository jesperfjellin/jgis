// Finds what to test by asking GeoServer: tile layers (OGC API Tiles, with the
// zoom range and bounds from TileJSON), feature layers (OGC API Features), and
// test areas where the data is dense. Run once per test by run.sh; the result
// is passed to every run as settings, so runs are repeatable.
//
// Areas: the centres of randomly sampled features. Layers are picked in
// proportion to their feature count, then a random feature in the layer, so
// areas follow the data: dense places (towns, cities) come up more often, as
// with real users. Samples closer than AREA_SPREAD are merged. Sampling uses
// the paging parameter from GeoServer's own "next" links (startIndex).
//
// Deep pages are slow on large tables (seconds each), so the result is cached
// in results/.discovery-cache.json and reused while GeoServer publishes the
// same collections and the discovery settings are unchanged.

import http from 'k6/http';
import { rng } from './lib/geo.js';

const DEFAULTS = JSON.parse(open('./lib/defaults.json'));
const env = (name) => (__ENV[name] !== undefined && __ENV[name] !== '' ? __ENV[name] : DEFAULTS[name]);
const BASE_URL = env('BASE_URL');
const WORKSPACE = env('WORKSPACE');
const SEED = Number(env('SEED'));
const AREA_COUNT = Number(__ENV.DISCOVERY_AREAS || 10);
// Spread of each area (how far users pan around its centre), in degrees.
const AREA_SPREAD = Number(__ENV.DISCOVERY_SPREAD || 0.1);
const OUT = __ENV.DISCOVERY_OUT;
const CACHE = 'results/.discovery-cache.json';

let cached = null;
try {
  cached = JSON.parse(open(`./${CACHE}`));
} catch (e) {
  cached = null;
}

export const options = { vus: 1, iterations: 1, setupTimeout: '15m', summaryTrendStats: ['avg'] };

function getJson(url) {
  const res = http.get(url, { tags: { name: 'discovery' } });
  if (res.status !== 200) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.json();
}

function inWorkspace(id) {
  return !WORKSPACE || id.startsWith(`${WORKSPACE}:`);
}

const short = (id) => (WORKSPACE ? id.slice(WORKSPACE.length + 1) : id);

export function setup() {
  const tiles = getJson(`${BASE_URL}/ogc/tiles/v1/collections?f=application/json`).collections || [];
  const features = getJson(`${BASE_URL}/ogc/features/v1/collections?f=application/json`).collections || [];
  const hasVector = (c) => (c.links || []).some((l) => l.rel && l.rel.endsWith('tilesets-vector'));
  const tileIds = tiles.filter((c) => inWorkspace(c.id) && hasVector(c)).map((c) => c.id);
  const featureIds = features.filter((c) => inWorkspace(c.id)).map((c) => c.id);
  if (tileIds.length === 0) throw new Error(`No vector tile layers found${WORKSPACE ? ` in workspace ${WORKSPACE}` : ''}`);

  // Bump VERSION when the discovery method changes, so old cache entries are not reused.
  // GeoServer does not list collections in a fixed order, so the ids are sorted for the key.
  const key = JSON.stringify({
    VERSION: 2, BASE_URL, WORKSPACE, SEED, AREA_COUNT, AREA_SPREAD,
    tileIds: [...tileIds].sort(), featureIds: [...featureIds].sort(),
  });
  if (cached && cached.key === key) return { ...cached.result, cached: true };

  // Zoom range and bounds per tile layer.
  const info = {};
  for (const id of tileIds) {
    const tj = getJson(`${BASE_URL}/ogc/tiles/v1/collections/${id}/tiles/WebMercatorQuad/metadata?f=application/json`);
    info[id] = { minzoom: tj.minzoom ?? 0, maxzoom: tj.maxzoom ?? 24, bounds: tj.bounds ?? [-180, -85, 180, 85] };
  }

  // Feature counts, and the paging parameter from a "next" link.
  const items = (id) => `${BASE_URL}/ogc/features/v1/collections/${id}/items?f=application/geo%2Bjson`;
  const counts = {};
  let pageParam = null;
  for (const id of featureIds) {
    const page = getJson(`${items(id)}&limit=1`);
    counts[id] = Number(page.numberMatched || 0);
    const next = (page.links || []).find((l) => l.rel === 'next');
    const m = next && next.href.match(/[?&](startIndex|offset|startindex)=/);
    if (m && !pageParam) pageParam = m[1];
  }
  const layers = featureIds.filter((id) => counts[id] > 0);
  const total = layers.reduce((sum, id) => sum + counts[id], 0);
  if (!pageParam || total === 0) throw new Error('Cannot sample features (no counts or paging); set AREAS');

  const rand = rng(SEED * 7 + 13);
  const firstCoord = (c) => (Array.isArray(c[0]) ? firstCoord(c[0]) : c);
  const samples = [];
  for (let i = 0; i < AREA_COUNT * 2; i++) {
    let r = rand() * total;
    let layer = layers[0];
    for (const id of layers) {
      if ((r -= counts[id]) < 0) { layer = id; break; }
    }
    const index = Math.floor(rand() * counts[layer]);
    const page = getJson(`${items(layer)}&limit=1&${pageParam}=${index}`);
    const f = (page.features || [])[0];
    if (f && f.geometry) {
      const [lon, lat] = firstCoord(f.geometry.coordinates);
      samples.push({ layer, lon: Number(lon.toFixed(4)), lat: Number(lat.toFixed(4)) });
    }
  }

  // Merge samples closer than AREA_SPREAD; keep the first AREA_COUNT areas.
  const areas = [];
  for (const smp of samples) {
    const near = areas.find((a) => Math.abs(a[0] - smp.lon) < AREA_SPREAD && Math.abs(a[1] - smp.lat) < AREA_SPREAD / 2);
    if (!near && areas.length < AREA_COUNT) areas.push([smp.lon, smp.lat, AREA_SPREAD]);
  }

  const result = {
    WORKSPACE: WORKSPACE || '',
    TILE_LAYERS: tileIds.map(short).join(','),
    WMS_LAYERS: tileIds.map(short).join(','),
    FEATURE_LAYERS: featureIds.map(short).join(','),
    AREAS: JSON.stringify(areas),
    layers: info,
    feature_counts: counts,
    samples,
  };
  return { ...result, key, cached: false };
}

export default function () {}

export function handleSummary(data) {
  const d = data.setup_data;
  const settings = ['TILE_LAYERS', 'WMS_LAYERS', 'FEATURE_LAYERS', 'AREAS'].map((k) => `${k}=${d[k]}`).join('\n');
  const { key, cached: wasCached, ...result } = d;
  const out = {
    [`${OUT}/discovery.env`]: `${settings}\nDISCOVERY_CACHED=${wasCached}\n`,
    [`${OUT}/discovery.json`]: JSON.stringify(result, null, 2),
  };
  if (!wasCached) out[CACHE] = JSON.stringify({ key, result }, null, 2);
  return out;
}
