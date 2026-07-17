//
//  MarketStore.swift
//  CryptoSim
//
//  Shared, observable market state for the whole app (all four tabs read
//  coin prices from here). Owns the refresh cycle: TTL-based caching,
//  stale-data fallback on failure, and load-state the UI can render.
//
//  v1 equivalent: CryptoService (a singleton that mixed transport,
//  decoding, caching, and UI state). v2 splits transport (NetworkClient),
//  domain API (MarketDataProviding), and observable state (this store),
//  with every dependency injected.
//

import Foundation
import Combine

@MainActor
final class MarketStore: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        /// Failed, but `coins` may still hold usable stale data.
        case failed(message: String)
    }

    @Published private(set) var coins: [CoinMarketData] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var lastUpdated: Date?

    private let service: MarketDataProviding
    private let analytics: AnalyticsTracking
    private let cacheTTL: TimeInterval

    /// Prevents overlapping refreshes (timer + pull-to-refresh racing).
    private var inFlightRefresh: Task<Void, Never>?

    init(
        service: MarketDataProviding,
        analytics: AnalyticsTracking,
        cacheTTL: TimeInterval = 30
    ) {
        self.service = service
        self.analytics = analytics
        self.cacheTTL = cacheTTL
    }

    var isLoading: Bool { loadState == .loading }

    var errorMessage: String? {
        if case .failed(let message) = loadState { return message }
        return nil
    }

    /// Refreshes the coin list. Respects the TTL cache unless forced, and
    /// coalesces concurrent callers onto one in-flight request.
    func refresh(force: Bool = false, source: AnalyticsEvent.RefreshSource) async {
        if let existing = inFlightRefresh {
            await existing.value
            return
        }

        if !force, !coins.isEmpty,
           let lastUpdated,
           Date().timeIntervalSince(lastUpdated) < cacheTTL {
            AppLog.network.debug("Refresh skipped — cache still fresh")
            return
        }

        let task = Task { await performRefresh(source: source) }
        inFlightRefresh = task
        await task.value
        inFlightRefresh = nil
    }

    private func performRefresh(source: AnalyticsEvent.RefreshSource) async {
        loadState = .loading
        do {
            let fetched = try await service.fetchTopCoins()
            coins = fetched
            lastUpdated = Date()
            loadState = .loaded
            analytics.track(.marketRefreshed(source: source, coinCount: fetched.count))
        } catch {
            let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            loadState = .failed(message: message)
            analytics.track(.marketRefreshFailed(reason: message))
            AppLog.network.error("Market refresh failed: \(message, privacy: .public)")
        }
    }

    /// Chart data passthrough (no caching — charts are per-screen, on demand).
    func priceChart(coinId: String, days: Int) async throws -> [Double] {
        try await service.fetchPriceChart(coinId: coinId, days: days)
    }

    func coin(withId id: String) -> CoinMarketData? {
        coins.first { $0.id == id }
    }
}
