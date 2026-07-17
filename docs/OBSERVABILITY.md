# Observability

Three instruments, one principle: **you can't fix what you can't see.** Everything here is local/on-device (no third-party SDK), but each piece is shaped exactly like its production counterpart, and the protocols are the seams where a real backend would plug in.

## 1. Structured logging — `AppLog`

`os.Logger` split into categories under the app's bundle-id subsystem:

| Category | Contents |
|---|---|
| `network` | request outcomes, latencies, retries, rate limits |
| `trading` | executed trades, rejected trades |
| `persistence` | container setup/fallback, load counts, save failures |
| `ui` | screen-level failures (e.g. chart load) |
| `analytics` | mirror of the analytics event stream |

Why `os.Logger` and not `print`: log levels (a `fault` for the container fallback is triageable; a `debug` for cache skips is free), privacy annotations, near-zero cost when not captured, and filtering in Console.app by subsystem/category:

```
log stream --predicate 'subsystem == "AyyanQamer.CryptoSim" AND category == "trading"'
```

## 2. Analytics — `AnalyticsEvent` + `AnalyticsTracking`

Every event the app can emit is one case of the `AnalyticsEvent` enum — typo-proof at call sites, reviewable in one file, with typed properties (`trade_executed` carries coin_id/side/amount/total_value). Events follow warehouse conventions: snake_case names, string properties.

`AnalyticsTracking` is the protocol; implementations:
- `LocalAnalyticsTracker` — logs each event, keeps a 200-event ring buffer for the dashboard, persists lifetime counts to UserDefaults
- `NoOpAnalyticsTracker` — previews/tests
- (production would add: a batching uploader to Amplitude/Statsig/in-house — one new file, zero call-site changes)

Instrumentation points: refresh outcomes (with source: launch/timer/pull/retry/foreground), trades (executed *and* failed, with reason), watchlist changes, sheet opens, sort/search usage. The failure events are the valuable ones: a spike in `trade_failed{reason=insufficient_funds}` is a product signal.

## 3. Request metrics + in-app dashboard

`URLSessionNetworkClient` records a `RequestMetric` (endpoint, duration, status, outcome) for every attempt — including each retry — into `MetricsCollector`.

The **Metrics tab** (DEBUG builds only) renders the collector live:
- p50/p95 latency and error rate for the session
- per-endpoint request counts, average latency, failure counts
- lifetime analytics event counts and the live event stream

It's a pocket version of a service dashboard — the same shape as the Grafana/Scuba views used to watch a production rollout, and genuinely useful here for watching CoinGecko rate-limit behavior during development.

## Design notes

- Recording is thread-safe by hopping to `@MainActor` inside the collector/tracker; callers never block.
- Ring buffers cap memory (200 events / 500 request metrics).
- The dashboard reads `@Published` state — no polling.
- Percentiles use linear interpolation between ranks; with <20 requests p95 ≈ max, which is fine for a session-scoped debug view.
