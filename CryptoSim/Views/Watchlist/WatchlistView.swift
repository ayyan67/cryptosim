//
//  WatchlistView.swift
//  CryptoSim
//
//  Watchlist tab: starred coins with swipe-to-remove and an add sheet.
//

import SwiftUI
import UIKit

struct WatchlistView: View {
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore

    @State private var showingAddSheet = false

    private var watchedCoins: [CoinMarketData] {
        let watchlistIds = Set(portfolioStore.watchlistItems.map { $0.coinId })
        return marketStore.coins.filter { watchlistIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if watchedCoins.isEmpty {
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
            Text("Add coins from the Market tab to track them here")
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
        List(watchedCoins) { coin in
            NavigationLink(destination: CoinDetailView(coin: coin)) {
                WatchlistRow(coin: coin)
            }
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    portfolioStore.removeFromWatchlist(coinId: coin.id)
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
    @EnvironmentObject var portfolioStore: PortfolioStore

    var body: some View {
        HStack {
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                portfolioStore.removeFromWatchlist(coinId: coin.id)
            }) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .frame(width: 30)
            }
            .buttonStyle(PlainButtonStyle())

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
                    portfolioStore.addToWatchlist(coinId: coin.id)
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
