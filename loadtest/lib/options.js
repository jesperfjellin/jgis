import * as cfg from './config.js';

// Common k6 options. `url` is left out of the system tags so each request
// doesn't become its own time series in Prometheus; requests are grouped by
// the `name` (service) and `layer` tags instead.
export function options(scenarios) {
  return {
    scenarios,
    batchPerHost: 6,
    systemTags: ['status', 'method', 'name', 'scenario', 'expected_response', 'error_code'],
    summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  };
}

export function constantVus(exec) {
  return { executor: 'constant-vus', exec, vus: cfg.VUS, duration: cfg.DURATION, gracefulStop: '30s' };
}
