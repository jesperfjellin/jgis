// Tiles, WMS and features users at the same time. VUS is split 60/25/15.

import * as cfg from '../lib/config.js';
import { options as baseOptions } from '../lib/options.js';
import { tileLayerInfo, truncateTileCache } from '../lib/geoserver.js';

export { tiles } from './tiles.js';
export { wms } from './wms.js';
export { features } from './features.js';

const share = (fraction) => Math.max(1, Math.round(cfg.VUS * fraction));
const scenario = (exec, vus) => ({ executor: 'constant-vus', exec, vus, duration: cfg.DURATION, gracefulStop: '30s' });

export const options = baseOptions({
  tiles: scenario('tiles', share(0.6)),
  wms: scenario('wms', share(0.25)),
  features: scenario('features', share(0.15)),
});

export function setup() {
  if (__ENV.COLD_CACHE === 'true') truncateTileCache(cfg.TILE_LAYERS);
  return { layers: tileLayerInfo(cfg.TILE_LAYERS) };
}
