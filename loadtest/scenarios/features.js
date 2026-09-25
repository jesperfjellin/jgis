// Clients reading vector features with OGC API Features: for each map view, one
// items request per FEATURE_LAYERS layer for the view's bounding box.

import * as cfg from '../lib/config.js';
import { options as baseOptions, constantVus } from '../lib/options.js';
import { mapSession, fetchAll, featuresRequest } from '../lib/geoserver.js';

export const options = baseOptions({ features: constantVus('features') });

export function features() {
  mapSession((view) => {
    fetchAll(cfg.FEATURE_LAYERS.map((layer) => featuresRequest(layer, view.tiles)));
  });
}
