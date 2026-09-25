// Users browsing a map built from OGC API tiles (vector by default, or PNG map
// tiles with TILE_FORMAT=map). Each view requests the tiles of every layer
// visible at that zoom, skipping tiles already fetched in the session.
//
// COLD_CACHE=true empties GeoWebCache for these layers before the run, so the
// first requests render tiles from PostGIS instead of reading the cache.

import * as cfg from '../lib/config.js';
import { options as baseOptions } from '../lib/options.js';
import { tileLayerInfo, truncateTileCache, mapSession, fetchAll, tileRequest, tileInBounds } from '../lib/geoserver.js';

export const options = baseOptions({ tiles: { exec: 'tiles', vus: cfg.VUS } });

export function setup() {
  if (cfg.COLD_CACHE) truncateTileCache(cfg.TILE_LAYERS);
  return { layers: tileLayerInfo(cfg.TILE_LAYERS) };
}

export function tiles(data) {
  mapSession((view, seen) => {
    const requests = [];
    for (const layer of cfg.TILE_LAYERS) {
      const info = data.layers[layer];
      if (view.z < info.min || view.z > info.max) continue;
      for (const t of view.tiles) {
        if (!tileInBounds(t, info.bounds)) continue;
        const req = tileRequest(layer, t, cfg.TILE_FORMAT);
        if (!seen.has(req.url)) {
          seen.add(req.url);
          requests.push(req);
        }
      }
    }
    fetchAll(requests);
  });
}
