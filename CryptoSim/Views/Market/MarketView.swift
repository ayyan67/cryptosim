//
//  MarketView.swift
//  CryptoSim
//
//  Market tab: searchable, sortable list of the top coins with inline Buy.
//  Data comes from the shared MarketStore; search/sort presentation logic
//  lives in MarketViewModel.
//

import SwiftUI

struct MarketView: View {
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore
    @StateObject private var viewModel = MarketViewModel()

    @State private var selectedCoin: CoinMarketData?

    private var displayCoins: [CoinMarketData] {
        viewModel.displayCoins(from: marketStore.coins)
    }

    var body: some View {
        NavigationStack {
            Group {
                if marketStore.isLoading && marketStore.coins.isEmpty {
                    loadingState
                } else if let error = marketStore.errorMessage, marketStore.coins.isEmpty {
                    errorState(error)
                } else {
                    coinList
                }
            }
            .navigationTitle("Market")
            .searchable(text: $viewModel.searchText, prompt: "Search coins")
            .toolbar { sortMenu }
            .background(Color.appBackground)
            .refreshable {
                await marketStore.refresh(force: true, source: .pullToRefresh)
            }
            .sheet(item: $selectedCoin) { coin in
                TradeSheet(coin: coin, side: .buy)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading market data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("Unable to load data")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await marketStore.refresh(force: true, source: .retryButton)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var coinList: some View {
        List(displayCoins) { coin in
            NavigationLink(destination: CoinDetailView(coin: coin)) {
                MarketRow(coin: coin) {
                    selectedCoin = coin
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    private var sortMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("Sort by", selection: $viewModel.sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }

                Divider()

                Button(action: { viewModel.sortAscending.toggle() }) {
                    Label(
                        viewModel.sortAscending ? "Ascending" : "Descending",
                        systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                    )
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }
}

struct MarketRow: View {
    let coin: CoinMarketData
    let onBuyTapped: () -> Void

    var body: some View {
        HStack {
            CoinIconView(imageURL: coin.image, symbol: coin.symbol)

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

            Button(action: onBuyTapped) {
                Text("Buy")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}
