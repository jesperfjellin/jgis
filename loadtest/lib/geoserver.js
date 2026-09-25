// Request builders and a simple model of a user browsing a map.

import http from 'k6/http';
import { check, sleep } from 'k6';
import encoding from 'k6/encoding';
import * as cfg from './config.js';
import { lonLatToTile, tileBbox3857, tileBbox4326, viewTiles, rng, pick, weighted } from './geo.js';

const MVT = 'application/vnd.mapbox-vector-tile';

// ---------------------------------------------------------------------------
// Setup helpers (run once per test, in setup())
// ---------------------------------------------------------------------------

// Reads each layer's zoom range and bounds from GeoServer's TileJSON, so tiles
// are only requested where the layer has content, as a map client would.
// GeoServer derives the zoom range from the layer's style and answers tiles
// outside the bounds with 404.
export function tileLayerInfo(layers) {
  const info = {};
  for (const layer of layers) {
    const url = `${cfg.BASE_URL}/ogc/tiles/v1/collections/${cfg.WORKSPACE}:${layer}/tiles/WebMercatorQuad/metadata?f=application/json`;
    const res = http.get(url, { tags: { name: 'setup' } });
    if (res.status !== 200) throw new Error(`No TileJSON for ${layer} (HTTP ${res.status}): ${url}`);
    const tj = res.json();
    info[layer] = { min: tj.minzoom ?? 0, max: tj.maxzoom ?? 24, bounds: tj.bounds ?? [-180, -85, 180, 85] };
  }
  return info;
}

// Empties GeoWebCache for the given layers, so the test measures rendering
// instead of cache reads.
export function truncateTileCache(layers) {
  if (!cfg.ADMIN_PASSWORD) throw new Error('GEOSERVER_ADMIN_PASSWORD is needed to truncate the tile cache');
  const auth = `Basic ${encoding.b64encode(`${cfg.ADMIN_USER}:${cfg.ADMIN_PASSWORD}`)}`;
  for (const layer of layers) {
    const res = http.post(
      `${cfg.BASE_URL}/gwc/rest/masstruncate`,
      `<truncateLayer><layerName>${cfg.WORKSPACE}:${layer}</layerName></truncateLayer>`,
      { headers: { 'Content-Type': 'text/xml', Authorization: auth }, tags: { name: 'setup' } },
    );
    if (res.status !== 200) throw new Error(`Truncating ${layer} failed (HTTP ${res.status})`);
  }
}

// ---------------------------------------------------------------------------
// Map session
// ---------------------------------------------------------------------------

// A session is a few map views: the user lands somewhere, then pans or zooms.
// fetchView(view, seen) is called for each view; `seen` holds the keys of
// requests made earlier in the session, which a browser would have cached.
export function mapSession(fetchView, views = 5) {
  const rand = rng(cfg.SEED * 1000003 + __VU * 7919 + __ITER);
  const [lon, lat, spread] = pick(rand, cfg.AREAS);
  let z = weighted(rand, cfg.ZOOMS);
  let { x, y } = lonLatToTile(lon + (rand() - 0.5) * 2 * spread, lat + (rand() - 0.5) * spread, z);
  const seen = new Set();

  for (let i = 0; i < views; i++) {
    fetchView({ z, tiles: viewTiles(z, x, y, cfg.VIEW_COLS, cfg.VIEW_ROWS) }, seen);
    sleep(cfg.THINK_MIN + rand() * (cfg.THINK_MAX - cfg.THINK_MIN));

    const move = rand();
    if (move < 0.6) {
      // Pan by half a viewport in a random direction.
      x += Math.round((rand() - 0.5) * cfg.VIEW_COLS);
      y += Math.round((rand() - 0.5) * cfg.VIEW_ROWS);
    } else if (move < 0.8 && z < 18) {
      z += 1; x = x * 2 + 1; y = y * 2 + 1;
    } else if (z > 5) {
      z -= 1; x = Math.floor(x / 2); y = Math.floor(y / 2);
    }
  }
}

// Sends requests in parallel, at most 6 per host like a browser, and checks them.
export function fetchAll(requests) {
  if (requests.length === 0) return;
  const responses = http.batch(requests.map((r) => ['GET', r.url, null, { tags: r.tags, responseType: 'none' }]));
  for (const res of responses) check(res, { 'status is 200': (r) => r.status === 200 });
}

// ---------------------------------------------------------------------------
// Request builders
// ---------------------------------------------------------------------------

// True if the tile overlaps the layer's [minLon, minLat, maxLon, maxLat] bounds.
export function tileInBounds(t, bounds) {
  const [w, s, e, n] = tileBbox4326(t.z, t.x, t.y);
  return e >= bounds[0] && w <= bounds[2] && n >= bounds[1] && s <= bounds[3];
}

export function tileRequest(layer, t, format) {
  const coll = `${cfg.BASE_URL}/ogc/tiles/v1/collections/${cfg.WORKSPACE}:${layer}`;
  return format === 'map'
    ? { url: `${coll}/map/tiles/WebMercatorQuad/${t.z}/${t.y}/${t.x}?f=image/png`, tags: { name: 'ogcapi-maptiles', layer } }
    : { url: `${coll}/tiles/WebMercatorQuad/${t.z}/${t.y}/${t.x}?f=${MVT}`, tags: { name: 'ogcapi-tiles', layer } };
}

// One WMS GetMap per 256 px tile with all layers combined, like a tiled WMS
// source in OpenLayers or MapLibre.
export function wmsTileRequest(layers, t) {
  const names = layers.map((l) => `${cfg.WORKSPACE}:${l}`).join(',');
  const url =
    `${cfg.BASE_URL}/${cfg.WORKSPACE}/wms?SERVICE=WMS&REQUEST=GetMap&VERSION=1.1.1&LAYERS=${names}` +
    `&STYLES=&FORMAT=image/png&TRANSPARENT=TRUE&SRS=EPSG:3857&BBOX=${tileBbox3857(t.z, t.x, t.y)}&WIDTH=256&HEIGHT=256`;
  return { url, tags: { name: 'wms', layer: layers.join('+') } };
}

// OGC API Features items for the area covered by a set of tiles.
export function featuresRequest(layer, tiles, limit = 1000) {
  const boxes = tiles.map((t) => tileBbox4326(t.z, t.x, t.y));
  const bbox = [
    Math.min(...boxes.map((b) => b[0])),
    Math.min(...boxes.map((b) => b[1])),
    Math.max(...boxes.map((b) => b[2])),
    Math.max(...boxes.map((b) => b[3])),
  ].map((v) => v.toFixed(5));
  const url = `${cfg.BASE_URL}/ogc/features/v1/collections/${cfg.WORKSPACE}:${layer}/items?f=application/geo%2Bjson&limit=${limit}&bbox=${bbox.join(',')}`;
  return { url, tags: { name: 'ogcapi-features', layer } };
}
