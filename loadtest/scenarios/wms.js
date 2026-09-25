// Users browsing a map built from uncached WMS: one GetMap per 256 px tile with
// all WMS_LAYERS combined. Every request is rendered by GeoServer from PostGIS.

import * as cfg from '../lib/config.js';
import { options as baseOptions } from '../lib/options.js';
import { mapSession, fetchAll, wmsTileRequest } from '../lib/geoserver.js';

export const options = baseOptions({ wms: { exec: 'wms', vus: cfg.VUS } });

export function wms() {
  mapSession((view, seen) => {
    const requests = [];
    for (const t of view.tiles) {
      const req = wmsTileRequest(cfg.WMS_LAYERS, t);
      if (!seen.has(req.url)) {
        seen.add(req.url);
        requests.push(req);
      }
    }
    fetchAll(requests);
  });
}
