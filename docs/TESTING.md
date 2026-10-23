# Testing

73 unit tests, 7 suites, <1s total. Run with `⌘U` in Xcode or:

```bash
xcodebuild -project CryptoSim.xcodeproj -scheme CryptoSim \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Strategy

Test the layers where being wrong is expensive, using the seams the architecture provides:

| Suite | What it protects | Doubles used |
|---|---|---|
| `PortfolioStoreTests` (20) | Money math: average cost, cash conservation, oversell/overspend rejection, dust cleanup, valuation fallbacks, persistence round-trip, reset, watchlist snapshots | In-memory SwiftData container, `AnalyticsSpy` |
| `TradeViewModelTests` (12) | Trade validation: every rejection reason, comma-decimal parsing, quick-percent fills, MAX-fill floors-not-rounds regression | Real `PortfolioStore` over in-memory container |
| `MarketViewModelTests` (11) | Search + sort, incl. the strict-weak-ordering regression test | none (pure logic) |
| `MarketStoreTests` (9) | Refresh lifecycle: TTL cache, forced refresh, stale-data-on-failure, auto-refresh timer, scene-phase gating | `MockMarketDataService` |
| `NetworkClientTests` (7) | Status mapping, retry-on-transient, no-retry-on-429, metrics emission | `StubURLProtocol` (no real network) |
| `CoinDecodingTests` (4) | API contract: real CoinGecko fixture incl. null fields, malformed chart entries | JSON fixture file |
| `FormattersTests` (10) | Display formatting edge cases: grouping, zero, floating-point residue, sub-cent precision, trimming, floor, parsing | none |

## Conventions

- **Fixture factory** — `makeCoin(...)` builds a valid coin with defaults so each test states only what it cares about.
- **In-memory SwiftData** — each test gets a fresh `ModelContainer(isStoredInMemoryOnly: true)`: real persistence behavior, zero disk, zero cross-test bleed. `testStateSurvivesStoreReload` proves round-tripping by building a second store over the same container.
- **`StubURLProtocol`** — queues canned responses inside URLSession itself, so retry behavior is tested through the real session machinery rather than around it.
- **Spies over mocks with expectations** — `AnalyticsSpy` just records; assertions read its log. Simpler and less brittle.

## What's deliberately not tested (yet)

- **SwiftUI view bodies** — no snapshot tests. Next step would be snapshot testing (pointfree's library) for the chart renderer, the one view with real drawing logic.
- **UI flows** — no XCUITest. The buy→portfolio→history flow is the candidate acceptance test.
- **`LocalAnalyticsTracker`/`MetricsCollector` aggregation** — thin enough that the dashboard exercises them; percentile math would be the first thing to cover if they grew.
