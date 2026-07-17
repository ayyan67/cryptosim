//
//  MarketViewModel.swift
//  CryptoSim
//
//  Presentation logic for the Market tab: search + sort. Kept separate
//  from MarketStore (which owns shared data/refresh) so this logic is a
//  pure function of (coins, searchText, sortOption) and trivially testable.
//

import Foundation
import Combine

enum SortOption: String, CaseIterable {
    case marketCap = "Market Cap"
    case price = "Price"
    case change = "24h Change"
    case name = "Name"
}

@MainActor
final class MarketViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var sortOption: SortOption = .marketCap
    @Published var sortAscending = false

    private let analytics: AnalyticsTracking

    init(analytics: AnalyticsTracking = NoOpAnalyticsTracker()) {
        self.analytics = analytics
    }

    /// The rows the Market list should display for the given source data.
    func displayCoins(from coins: [CoinMarketData]) -> [CoinMarketData] {
        sortCoins(searchCoins(coins, query: searchText))
    }

    func searchCoins(_ coins: [CoinMarketData], query: String) -> [CoinMarketData] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return coins }
        let lowercased = trimmed.lowercased()
        return coins.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.symbol.lowercased().contains(lowercased)
        }
    }

    /// Sorts with an explicit ascending/descending key comparison.
    ///
    /// v1 implemented "ascending" by negating the comparator's result
    /// (`sortAscending ? !result : result`), which violates strict weak
    /// ordering for equal elements — a latent crash with `sorted(by:)`.
    /// Here each branch compares consistently in the requested direction.
    func sortCoins(_ coins: [CoinMarketData]) -> [CoinMarketData] {
        switch sortOption {
        case .marketCap:
            return sorted(coins, by: { $0.marketCap ?? 0 })
        case .price:
            return sorted(coins, by: { $0.currentPrice })
        case .change:
            return sorted(coins, by: { $0.priceChangePercentage24h ?? 0 })
        case .name:
            if sortAscending {
                return coins.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            } else {
                return coins.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
            }
        }
    }

    private func sorted(_ coins: [CoinMarketData], by key: (CoinMarketData) -> Double) -> [CoinMarketData] {
        sortAscending
            ? coins.sorted { key($0) < key($1) }
            : coins.sorted { key($0) > key($1) }
    }

    func trackSortChanged() {
        analytics.track(.sortChanged(option: sortOption.rawValue, ascending: sortAscending))
    }

    func trackSearch(resultCount: Int) {
        analytics.track(.searchPerformed(resultCount: resultCount))
    }
}
