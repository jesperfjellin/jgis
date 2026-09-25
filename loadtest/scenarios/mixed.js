// Tiles, WMS and features users at the same time. VUS is split 60/25/15.

import * as cfg from '../lib/config.js';
import { options as baseOptions } from '../lib/options.js';
import { tileLayerInfo, truncateTileCache } from '../lib/geoserver.js';

export { tiles } from './tiles.js';
export { wms } from './wms.js';
export { features } from './features.js';

const share = (fraction) => Math.max(1, Math.round(cfg.VUS * fraction));

export const options = baseOptions({
  tiles: { exec: 'tiles', vus: share(0.6) },
  wms: { exec: 'wms', vus: share(0.25) },
  features: { exec: 'features', vus: share(0.15) },
});

export function setup() {
  if (cfg.COLD_CACHE) truncateTileCache(cfg.TILE_LAYERS);
  return { layers: tileLayerInfo(cfg.TILE_LAYERS) };
}
