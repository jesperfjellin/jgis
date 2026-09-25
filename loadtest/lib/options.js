import * as cfg from './config.js';

// Common k6 options. `url` is left out of the system tags so each request
// doesn't become its own time series in Prometheus; requests are grouped by
// the `name` (service) and `layer` tags instead.
//
// scenarios: { name: { exec, vus } }. With WARMUP set, each scenario gets a
// "<name>_warmup" twin that runs first, and the measured scenario starts after it.
export function options(scenarios) {
  const all = {};
  for (const [name, { exec, vus }] of Object.entries(scenarios)) {
    const base = { executor: 'constant-vus', exec, vus, gracefulStop: '30s' };
    if (cfg.WARMUP) {
      all[`${name}_warmup`] = { ...base, duration: cfg.WARMUP, gracefulStop: '0s' };
      all[name] = { ...base, duration: cfg.DURATION, startTime: cfg.WARMUP };
    } else {
      all[name] = { ...base, duration: cfg.DURATION };
    }
  }
  return {
    scenarios: all,
    batchPerHost: 6,
    systemTags: ['status', 'method', 'name', 'scenario', 'expected_response', 'error_code'],
    summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  };
}
