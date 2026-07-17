# v1 → v2: What changed and why

v1 was the app I submitted for COSC 4355 — it worked, demoed well, and got the grade. After ~a year shipping production iOS on WhatsApp Payments, I reread it with production eyes and rebuilt it. This file is the honest changelog: each change names the v1 behavior, the problem, and what v2 does — because "walk me through what you'd redo" is the most useful question you can ask about your own old code.

## 1. Crash-on-launch `fatalError` → graceful degradation

**v1:** `CryptoAppApp.init` called `fatalError("Could not create ModelContainer")` if SwiftData failed to open. Any disk-full/migration issue = guaranteed crash loop.

**v2:** Falls back to an in-memory container — the session works, trades just don't persist — and logs a `fault` so the failure is visible. At WhatsApp I removed 15+ crash-prone `fatalError` sites for exactly this reason: a degraded session beats a crash, always.

## 2. Singleton service → protocol-based dependency injection

**v1:** `CryptoService.shared` — a singleton mixing transport, decoding, caching, and UI state (`@Published var coins`, `isLoading`, `errorMessage` all on the network class). Untestable without hitting the real API.

**v2:** Four separable layers: `NetworkClient` (transport) → `MarketDataProviding` (domain API) → `MarketStore` (observable state) → view models. Each seam has a protocol; the whole graph is wired once in the composition root. Tests inject mocks anywhere.

## 3. No tests → 72 unit tests

**v1:** Zero tests. The money math (average cost basis, cash conservation) was verified by tapping around in the simulator.

**v2:** XCTest suites over trade invariants, valuation fallbacks, validation, search/sort, retry/rate-limit behavior, and decoding against a real API fixture (nulls included). In-memory SwiftData containers keep the whole suite under a second. The test that matters most: buy twice at different prices and assert the volume-weighted average cost — the calculation users would screenshot if it were wrong.

## 4. `Bool` returns and string errors → typed errors

**v1:** `buyCoin(...) -> Bool`; the view guessed the failure reason ("Insufficient funds") from context. API errors were free-form strings.

**v2:** `buy(...) throws` with `TradeError.insufficientFunds(needed:available:)` — the error message can say exactly what's wrong, tests can assert exact failures, and analytics gets a machine-readable reason. Same for `APIError` (rate-limited vs. server vs. transport vs. decoding), which the retry logic branches on.

## 5. Latent sort crash (strict weak ordering violation)

**v1:** "Ascending" sort was implemented by negating the comparator: `return sortAscending ? !result : result`. For equal elements, `a<b == false` and `b<a == false`, so negation claims *both* orderings hold — an invalid comparator that `sorted(by:)` is allowed to crash on (and does, in debug builds, given equal market caps).

**v2:** Direction-aware key comparisons (`key($0) < key($1)` vs `>`), plus a regression test with equal keys. Found it by reading the code, the way a reviewer would.

## 6. No observability → logging, analytics, metrics

**v1:** One `print()` in a catch block.

**v2:**
- `os.Logger` with categories (network/trading/persistence/ui/analytics) — filterable in Console.app
- Typed `AnalyticsEvent` enum (12 events) through an `AnalyticsTracking` protocol — the local tracker logs + buffers + persists lifetime counts; a production backend would be a one-file swap
- `MetricsCollector` records every request's latency and outcome; the DEBUG-only **Metrics tab** shows p50/p95 latency, error rate, per-endpoint breakdown, and the live event stream

This mirrors the WhatsApp lesson that you can't fix what you can't see — I once root-caused a telemetry gap that was hiding ~1,900× the errors we thought we had.

## 7. Refresh cycle: background-blind timer → scene-aware, coalesced

**v1:** A 30s timer force-refreshed unconditionally, and pull-to-refresh could overlap it — double-tapping a rate-limited free API.

**v2:** Timer only fires while the scene is active; foregrounding triggers an immediate refresh; `MarketStore` coalesces concurrent refresh calls onto one in-flight task; failures keep stale data on screen with an explanatory message instead of blanking the UI. Retries use exponential backoff and deliberately skip 429s.

## 8. Stringly-typed data → domain types

**v1:** `transaction.type == "BUY"` string comparisons; magic epsilon `0.00000001` inline; time-range arrays duplicated per view.

**v2:** `TransactionType` enum (stored as a raw value for SwiftData, enum-only API), named `dustThreshold` constant with a comment explaining floating-point dust, constants hoisted.

## 9. UI correctness details

- **Race at startup (v1):** `PortfolioManager.configure(with:)` was called in `.onAppear` — views could query the store before it had a ModelContext. v2 constructs `PortfolioStore` with its context in the app init; there is no unconfigured state.
- **Locale parsing:** v1's `Double(amountText)` rejects "0,5" from comma-decimal locales. v2 parses both.
- **Chart request races:** v1 fired an unstructured `Task` per time-range tap; rapid taps could resolve out of order. v2 uses `.task(id:)` for automatic cancellation.
- **`sheet(item:)` over `sheet(isPresented:) + optional`:** v1's pattern can present a sheet before `selectedCoin` is set. `sheet(item:)` makes the data drive the presentation.
- **Formatting:** cached `NumberFormatter`/`DateFormatter` (v1 allocated a DateFormatter per row render — they're expensive); thousands grouping ("$10,000.00"); zero renders "$0.00" not "$0.000000".
- **Valuation fallback:** v1 valued a holding at $0 if its live price was missing from the top-30 payload (a coin can drop out of the top 30!). v2 falls back to cost basis and has a test for it.

## 10. Navigation & flow audit (the "does it feel like one app?" pass)

After the architecture rework I did a dedicated UX-consistency pass, because v1's navigation felt stitched together:

- **Two competing detail screens → one.** v1 pushed `CoinDetailView` from Market/Watchlist but a *different* `HoldingsDetailView` from Portfolio — same coin, different screen, neither complete. v2 has one canonical, position-aware `CoinDetailView` (a "Your Position" section appears when you hold the coin — the Robinhood pattern). Fewer code paths, consistent mental model, and it structurally eliminates a crash risk: the old screen retained a `Holding` reference that selling the full position would delete out from under it; the merged screen queries the position live from the store.
- **Sheets vs. pushes, by rule.** Sheets are for modal tasks (trade, add-to-watchlist); hierarchy is pushed. v1 presented the Performance breakdown as a sheet with a Done button; it's drill-down content, so it's now a push.
- **Empty states that act.** "Buy some crypto to get started!" with no button is a dead end. A small `TabRouter` owns the tab selection, so Portfolio/History empty states have a "Browse Market" button that actually navigates.
- **No accidental destruction.** v1's watchlist row star was a bare tap target that instantly deleted the entry (and swipe-to-remove existed alongside it). The star is now an indicator; removal is deliberate — swipe, or the star in the detail toolbar.
- **Every list state renders something honest**: holdings and watchlist rows fall back to persisted snapshots ("price unavailable") when a coin drops out of the top-30 payload instead of silently vanishing; History shows "No matching transactions" when a filter matches nothing.
- **Quick-fill correctness**: the MAX button formatted the maximum with `"%.6f"`, which rounds to *nearest* — for some prices it rounded up past the affordable maximum and invalidated its own fill. Now floors at display precision, with a regression test.

## 11. Deliberate non-changes (tradeoffs I'd defend)

- **`Double` for money, still.** For a paper-trading simulator where values are display-only, `Double`'s error (~1e-12 relative) is invisible at 6 decimal places, and SwiftData/charts interop is simpler. A real payments product needs `Decimal` end to end — at WhatsApp money was integer minor-units + currency code on the wire. Migrating this app is mechanical and on the roadmap; knowing *when* the cost is justified is the actual skill.
- **Hand-rolled `Path` charts, not Swift Charts.** Building the normalization + gradient fill from scratch was the learning objective, it's dependency-free, and it renders 200+ points fine. Swift Charts would win the moment I need axes, scrubbing, or accessibility.
- **`ObservableObject`/Combine, not `@Observable`.** Matches the Combine-based refresh pipeline and the codebase I work in daily. `@Observable` migration is straightforward and would cut some invalidation overhead; it's listed as next work, not blocking work.
- **No full Coordinator layer.** Four tabs and one push-destination don't earn one — though `TabRouter` (which owns tab selection for programmatic navigation) is the seed of exactly that pattern. The moment navigation needs deep links or multi-step flows, `NavigationStack` paths join it in a real router — the store/VM layering doesn't change.
