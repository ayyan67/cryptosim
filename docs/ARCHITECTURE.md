# Architecture

CryptoSim v2 is MVVM with explicit dependency injection. The goal of the shape: **every piece of logic that can be wrong lives in a plain Swift type that a unit test can construct.**

## The layers

```
┌─────────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                            │
│  MarketView · PortfolioView · TradeSheet · CoinDetailView…  │
│  Render state, forward user intent. No business logic.      │
└──────────────┬──────────────────────────────────────────────┘
               │ @EnvironmentObject / @StateObject
┌──────────────▼──────────────────────────────────────────────┐
│  ViewModels (per-screen presentation logic)                 │
│  MarketViewModel — search + sort                            │
│  TradeViewModel — parsing, validation, quick-fills, execute │
├─────────────────────────────────────────────────────────────┤
│  Stores (shared observable app state, @MainActor)           │
│  MarketStore — coins, refresh cycle, TTL cache, load state  │
│  PortfolioStore — cash, holdings, transactions, watchlist   │
└──────────────┬──────────────────────────────────────────────┘
               │ protocols
┌──────────────▼──────────────────────────────────────────────┐
│  Services (domain API)                                      │
│  MarketDataProviding ← CoinGeckoMarketDataService           │
│  decodes payloads into domain models                        │
└──────────────┬──────────────────────────────────────────────┘
               │ protocol
┌──────────────▼──────────────────────────────────────────────┐
│  Networking (transport)                                     │
│  NetworkClient ← URLSessionNetworkClient                    │
│  status→error mapping, retry w/ backoff, latency metrics    │
└─────────────────────────────────────────────────────────────┘

Cross-cutting: Observability (AppLog, AnalyticsTracking, MetricsCollector)
Persistence:   SwiftData via PortfolioStore only
```

## Composition root

`CryptoSimApp.init` is the only place concrete types are constructed and wired:

```swift
let metrics = MetricsCollector()
let analytics = LocalAnalyticsTracker()
let networkClient = URLSessionNetworkClient(metrics: metrics)
let marketService = CoinGeckoMarketDataService(client: networkClient)
MarketStore(service: marketService, analytics: analytics)
PortfolioStore(modelContext: container.mainContext, analytics: analytics)
```

Nothing below this file uses a singleton. Tests build the same graph with mocks at whichever seam they care about (`MockMarketDataService`, `StubURLProtocol`, `AnalyticsSpy`).

## Why stores *and* view models?

Two different kinds of state exist:

- **Shared domain state** — the coin list and the user's portfolio are read by all four tabs. That belongs in long-lived stores injected via the environment. Duplicating it per screen would mean four competing refresh cycles and inconsistent balances.
- **Per-screen presentation state** — search text, sort order, an in-progress trade amount. That belongs to the screen (`@StateObject` view model), dies with the screen, and is pure enough to test exhaustively.

A screen with no real presentation logic (History, Watchlist) doesn't get a ceremonial view model; it filters store data inline. Pattern where it pays, not everywhere.

## Data flow examples

**App launch:**
`CryptoSimApp` builds the graph → `RootTabView.task` → `MarketStore.refresh(source: .appLaunch)` → service → client → CoinGecko → decoded `[CoinMarketData]` published → all tabs re-render. In parallel, `PortfolioStore.init` loads holdings/transactions/watchlist/cash from SwiftData.

**Buy flow:**
TradeSheet binds a text field to `TradeViewModel.amountText` → `validationIssue` recomputes on each keystroke (button disabled state) → confirm → `viewModel.execute()` → `PortfolioStore.buy` checks invariants, throws typed `TradeError` on violation → on success: cash deducted, holding upserted with volume-weighted average cost, `Transaction` recorded, one SwiftData save, `trade_executed` analytics event → `@Published` changes propagate to Portfolio/History tabs automatically.

**Refresh cycle:**
A 30s timer in `RootTabView` fires only while `scenePhase == .active`; foregrounding triggers an immediate (TTL-respecting) refresh. `MarketStore` coalesces overlapping refresh calls onto one in-flight task, so a timer tick and a pull-to-refresh can't double-hit the rate-limited API.

## Error handling policy

- **Transport**: typed `APIError`; transient failures (5xx, network) retried once with backoff; 429 never retried (retrying a rate limit makes it worse) — the UI shows stale data with a message instead.
- **Trading**: typed `TradeError` with associated values (`insufficientFunds(needed:available:)`) so messages are specific and tests are exact.
- **Persistence**: container failure falls back to in-memory storage (app stays usable, fault logged) instead of v1's `fatalError`. Save failures are logged, never crash.

## Concurrency model

- Stores and view models are `@MainActor` — published state only mutates on the main thread (the class of bug behind a Core Data threading crash I fixed at WhatsApp).
- The network client is actor-agnostic; async/await end to end from `URLSession` up.
- Chart loads use `.task(id: selectedRange)` so switching time ranges cancels the in-flight request instead of racing it.
