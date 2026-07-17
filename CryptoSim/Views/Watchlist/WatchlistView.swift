//
//  WatchlistView.swift
//  CryptoSim
//
//  Watchlist tab. Rows are driven by the persisted watchlist (not by
//  which coins happen to be in the current market payload), so a watched
//  coin that falls out of the top 30 still renders from its snapshot —
//  it just shows "price unavailable" instead of vanishing.
//
//  Removal is deliberate: swipe on the row, or the star in the coin's
//  detail toolbar. The row's star is an indicator, not a button — a bare
//  tap target that instantly deletes is an accidental-destruction trap.
//

import SwiftUI
import UIKit

struct WatchlistView: View {
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var analytics: LocalAnalyticsTracker

    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if portfolioStore.watchlistItems.isEmpty {
                    emptyState
                } else {
                    watchlist
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(Color.appBackground)
            .sheet(isPresented: $showingAddSheet) {
                AddToWatchlistSheet()
            }
            .onAppear {
                analytics.track(.screenViewed(name: "watchlist"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No coins in watchlist")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Track coins you're interested in without buying them")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Coins") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var watchlist: some View {
        List(portfolioStore.watchlistItems, id: \.coinId) { item in
            Group {
                if let coin = marketStore.coin(withId: item.coinId) {
                    NavigationLink(destination: CoinDetailView(coin: coin)) {
                        WatchlistRow(coin: coin)
                    }
                } else {
                    WatchlistFallbackRow(item: item)
                }
            }
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    portfolioStore.removeFromWatchlist(coinId: item.coinId)
                } label: {
                    Label("Remove", systemImage: "star.slash")
                }
            }
        }
        .listStyle(.plain)
    }
}

struct WatchlistRow: View {
    let coin: CoinMarketData

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .frame(width: 30)

            CoinIconView(imageURL: coin.image, symbol: coin.symbol, placeholderTint: .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)

                Text(coin.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(coin.formattedPrice)
                    .font(.headline)

                Text(coin.formattedChange)
                    .font(.subheadline)
                    .foregroundColor(coin.priceChangeIsPositive ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Shown when a watched coin isn't in the current market payload.
struct WatchlistFallbackRow: View {
    let item: WatchlistItem

    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .frame(width: 30)

            CoinIconView(imageURL: item.imageUrl, symbol: item.symbol, placeholderTint: .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.coinName.isEmpty ? item.coinId : item.coinName)
                    .font(.headline)

                Text(item.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("price unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddToWatchlistSheet: View {
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredCoins: [CoinMarketData] {
        let watchlistIds = Set(portfolioStore.watchlistItems.map { $0.coinId })
        let unwatched = marketStore.coins.filter { !watchlistIds.contains($0.id) }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return unwatched }
        let query = trimmed.lowercased()
        return unwatched.filter {
            $0.name.lowercased().contains(query) || $0.symbol.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCoins) { coin in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    portfolioStore.addToWatchlist(coin: coin)
                    dismiss()
                }) {
                    HStack {
                        CoinIconView(imageURL: coin.image, symbol: coin.symbol)

                        VStack(alignment: .leading) {
                            Text(coin.name)
                                .font(.headline)
                            Text(coin.symbol.uppercased())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search coins")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(Color.appBackground)
        }
    }
}
