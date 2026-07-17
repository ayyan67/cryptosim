//
//  CoinDetailView.swift
//  CryptoSim
//
//  The one canonical coin screen, reached identically from Market,
//  Watchlist, and Portfolio. It is position-aware: when the user holds
//  the coin, a "Your Position" section appears (queried live from the
//  store each render — nothing retains a Holding that a sell might
//  delete). Chart loads use .task(id:) so switching ranges cancels the
//  in-flight request instead of racing it.
//

import SwiftUI

struct CoinDetailView: View {
    let coin: CoinMarketData
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var analytics: LocalAnalyticsTracker

    @State private var showingBuySheet = false
    @State private var showingSellSheet = false
    @State private var selectedRangeIndex = 1 // default 1W (matches sparkline)
    @State private var chartData: [Double] = []
    @State private var isLoadingChart = false

    private static let timeRanges = ["1D", "1W", "1M", "3M", "1Y", "All"]
    private static let timeRangeDays = [1, 7, 30, 90, 365, 1825]

    private var isInWatchlist: Bool {
        portfolioStore.isInWatchlist(coinId: coin.id)
    }

    /// Queried live so a sell-everything immediately removes the section.
    private var holding: Holding? {
        portfolioStore.holding(for: coin.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                chartSection

                if let holding {
                    positionSection(holding)
                }

                marketStats

                actionButtons
            }
        }
        .navigationTitle(coin.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    portfolioStore.toggleWatchlist(coin: coin)
                }) {
                    Image(systemName: isInWatchlist ? "star.fill" : "star")
                        .foregroundColor(isInWatchlist ? .yellow : .primary)
                }
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingBuySheet) {
            TradeSheet(coin: coin, side: .buy)
        }
        .sheet(isPresented: $showingSellSheet) {
            TradeSheet(coin: coin, side: .sell)
        }
        .task(id: selectedRangeIndex) {
            await loadChart(days: Self.timeRangeDays[selectedRangeIndex])
        }
        .onAppear {
            analytics.track(.coinDetailOpened(coinId: coin.id))
        }
    }

    private var header: some View {
        VStack(spacing: 15) {
            CoinIconView(imageURL: coin.image, symbol: coin.symbol, size: 80)

            Text(coin.name)
                .font(.title)
                .fontWeight(.bold)

            Text(coin.symbol.uppercased())
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(coin.formattedPrice)
                .font(.system(size: 36, weight: .bold))

            HStack(spacing: 4) {
                Image(systemName: coin.priceChangeIsPositive ? "arrow.up.right" : "arrow.down.right")
                Text(coin.formattedChange)
            }
            .font(.subheadline)
            .foregroundColor(coin.priceChangeIsPositive ? .green : .red)
        }
        .padding(.top, 20)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Price Chart")
                .font(.headline)
                .padding(.horizontal)

            ChartView(
                data: chartData.isEmpty ? (coin.sparklineIn7d?.price ?? []) : chartData,
                isPositive: coin.priceChangeIsPositive
            )
            .frame(height: 200)
            .padding(.horizontal)
            .overlay {
                if isLoadingChart {
                    ProgressView()
                }
            }

            HStack {
                ForEach(0..<Self.timeRanges.count, id: \.self) { index in
                    Button(action: {
                        selectedRangeIndex = index
                        analytics.track(.chartRangeChanged(coinId: coin.id, days: Self.timeRangeDays[index]))
                    }) {
                        Text(Self.timeRanges[index])
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedRangeIndex == index ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedRangeIndex == index ? Color.blue : Color.clear)
                            .cornerRadius(8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }

    private func positionSection(_ holding: Holding) -> some View {
        let currentValue = holding.amount * coin.currentPrice
        let gainLoss = currentValue - holding.totalCost
        let gainLossPercentage = holding.totalCost > 0 ? (gainLoss / holding.totalCost) * 100 : 0

        return VStack(alignment: .leading, spacing: 15) {
            Text("Your Position")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatCard(
                        title: "You Own",
                        value: "\(Formatters.coinAmount(holding.amount)) \(coin.symbol.uppercased())"
                    )
                    StatCard(title: "Value", value: Formatters.currency(currentValue))
                }

                HStack(spacing: 12) {
                    StatCard(
                        title: "Avg Buy Price",
                        value: Formatters.currency(holding.averageBuyPrice)
                    )
                    StatCard(
                        title: "Total P&L",
                        value: "\(Formatters.signedCurrency(gainLoss)) (\(Formatters.signedPercent(gainLossPercentage)))",
                        valueColor: gainLoss >= 0 ? .green : .red
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var marketStats: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Market Stats")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatCard(title: "Market Cap", value: coin.formattedMarketCap)
                    StatCard(title: "24h Volume", value: coin.formattedVolume)
                }

                HStack(spacing: 12) {
                    StatCard(title: "Circulating Supply", value: coin.formattedCirculatingSupply)
                    StatCard(title: "Max Supply", value: coin.formattedMaxSupply)
                }
            }
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showingBuySheet = true }) {
                Text(holding != nil ? "Buy More" : "Buy")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }

            Button(action: { showingSellSheet = true }) {
                Text("Sell")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(holding != nil ? Color.red : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(holding == nil)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    private func loadChart(days: Int) async {
        // 1W is already covered by the sparkline that shipped with the
        // market payload — skip the extra request.
        if days == 7, let sparkline = coin.sparklineIn7d?.price, !sparkline.isEmpty {
            chartData = sparkline
            return
        }

        isLoadingChart = true
        defer { isLoadingChart = false }

        do {
            chartData = try await marketStore.priceChart(coinId: coin.id, days: days)
        } catch is CancellationError {
            // User switched ranges — the new .task takes over.
        } catch {
            AppLog.ui.error("Chart load failed for \(coin.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
