# CryptoSim — iOS Paper-Trading App

A SwiftUI + SwiftData iOS app that simulates crypto trading with a $10,000 paper balance against **live CoinGecko market data**: persistent holdings with average-cost P&L, a watchlist, full transaction history, and hand-rolled price charts.

Originally built as my COSC 4355 (iOS development) final project at the University of Houston. **v2 is a ground-up rework** applying what I learned shipping production iOS at WhatsApp (Meta): MVVM with dependency injection, typed errors, a unit-test suite over all money math, structured logging, analytics instrumentation, and an in-app metrics dashboard.

## Features

- **Portfolio** — total balance, cash, holdings with live P&L, performance breakdown, asset allocation, one-tap reset to $10K
- **Market** — top 30 coins by market cap, search, four sort modes, pull-to-refresh, inline buy
- **Coin detail** — one position-aware screen reached from every tab: chart with 6 time ranges (1D → All), "Your Position" (amount, value, avg cost, P&L) when held, market stats, buy/sell, watchlist star
- **Trading** — buy/sell sheet with live validation, quick-percent fills (25/50/75/MAX), confirmation dialog, haptics
- **Watchlist** — star coins, swipe to remove, add sheet with search; entries survive coins dropping out of the top 30
- **History** — every trade, filterable by buy/sell, searchable
- **Metrics (DEBUG builds)** — live API latency percentiles (p50/p95), error rate, per-endpoint breakdown, analytics event stream

## Tech

| Area | Choice |
|---|---|
| UI | SwiftUI (iOS 18.5+), custom `Path`-based charts |
| Architecture | MVVM: Views → ViewModels/Stores → Services → NetworkClient |
| State | `ObservableObject` stores injected via `.environmentObject` |
| Persistence | SwiftData (`Holding`, `Transaction`, `WatchlistItem`, `Portfolio`) |
| Networking | `URLSession` + async/await, protocol-based client with retry/backoff |
| API | CoinGecko v3 (free tier, no key), 30s TTL cache + rate-limit fallback |
| Observability | `os.Logger` categories, typed analytics events, request metrics |
| Testing | XCTest — 72 unit tests over stores, view models, networking, decoding |

## Running it

1. Open `CryptoSim.xcodeproj` in Xcode 16+
2. Select the **CryptoSim** scheme and any iOS 18.5+ simulator
3. Run (`⌘R`). No API key or configuration needed.

Run tests with `⌘U`, or:

```bash
xcodebuild -project CryptoSim.xcodeproj -scheme CryptoSim \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' test
```

## Project layout

```
CryptoSim/
├── App/            Entry point (composition root) + tab container
├── Models/         API models (Codable) + SwiftData models
├── Networking/     NetworkClient protocol, URLSession impl, endpoints, errors
├── Services/       MarketDataProviding protocol + CoinGecko implementation
├── Stores/         MarketStore (shared market state), PortfolioStore (user state)
├── ViewModels/     MarketViewModel (search/sort), TradeViewModel (validation)
├── Views/          One folder per feature + shared Components
├── Observability/  Logging, analytics, metrics, in-app dashboard
├── Utilities/      Cached formatters
└── Support/        Theme

CryptoSimTests/     Unit tests + mocks + API fixtures
docs/               Architecture, testing, observability, v1→v2 improvements
learning/           Guided code walkthroughs (start at learning/00_START_HERE.md)
interview/          Interview prep material
```

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layers, data flow, and why it's shaped this way
- [docs/IMPROVEMENTS.md](docs/IMPROVEMENTS.md) — everything that changed from the class version (v1) and why
- [docs/TESTING.md](docs/TESTING.md) — test strategy and how to run
- [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md) — logging, analytics, and the metrics dashboard

## Known limitations / next steps

- Money math uses `Double` — fine for a paper-trading display, but a real payments product needs `Decimal` (see IMPROVEMENTS.md for the tradeoff discussion)
- Top-30 coins only; pagination is the obvious next step
- No image caching beyond `URLCache` defaults for coin icons
- Analytics is local-only by design; the `AnalyticsTracking` protocol is the seam where a real backend would plug in
