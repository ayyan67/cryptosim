//
//  PortfolioView.swift
//  CryptoSim
//
//  Portfolio tab: total balance card, cash, and current holdings.
//

import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var analytics: LocalAnalyticsTracker
    @EnvironmentObject var router: TabRouter
    @State private var showingResetConfirmation = false

    private var totalBalance: Double {
        portfolioStore.totalPortfolioValue(coins: marketStore.coins)
    }

    private var totalGainLoss: Double {
        portfolioStore.totalGainLoss(coins: marketStore.coins)
    }

    private var totalGainLossPercentage: Double {
        portfolioStore.totalGainLossPercentage(coins: marketStore.coins)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard

                    performanceButton

                    cashCard

                    holdingsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Portfolio")
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            Label("Reset Portfolio", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Reset Portfolio?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset to \(Formatters.currency(PortfolioStore.startingBalance))", role: .destructive) {
                    portfolioStore.resetPortfolio()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears all holdings and transaction history. Your watchlist is kept.")
            }
            .refreshable {
                await marketStore.refresh(force: true, source: .pullToRefresh)
            }
            .onAppear {
                analytics.track(.screenViewed(name: "portfolio"))
            }
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 10) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Text(Formatters.currency(totalBalance))
                .font(.system(size: 40, weight: .bold))

            HStack(spacing: 4) {
                Text(Formatters.signedCurrency(totalGainLoss))
                Text("(\(Formatters.signedPercent(totalGainLossPercentage)))")
            }
            .font(.subheadline)
            .foregroundColor(totalGainLoss >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.gradientStart, Color.gradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundColor(.white)
        .cornerRadius(20)
        .padding(.horizontal)
    }

    // Performance is drill-down content within the portfolio hierarchy,
    // so it's a push (v1 presented it as a sheet — sheets are for modal
    // tasks like trading, not for navigation).
    private var performanceButton: some View {
        NavigationLink(destination: PerformanceView()) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View Performance")
                        .font(.headline)
                    Text("See detailed breakdown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }

    private var cashCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Available Cash")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(Formatters.currency(portfolioStore.cashBalance))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Holdings")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            if portfolioStore.holdings.isEmpty {
                emptyHoldings
            } else {
                // Every persisted holding gets a row. Coins with no live
                // price (dropped out of the top-30 payload) still render
                // from stored data — they just aren't tappable, since the
                // detail screen needs market data.
                ForEach(portfolioStore.holdings, id: \.coinId) { holding in
                    if let coin = marketStore.coin(withId: holding.coinId) {
                        NavigationLink(destination: CoinDetailView(coin: coin)) {
                            HoldingRow(holding: holding, coin: coin)
                        }
                    } else {
                        HoldingRow(holding: holding, coin: nil)
                    }
                }
            }
        }
    }

    private var emptyHoldings: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No holdings yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Buy some crypto to get started!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Browse Market") {
                router.selection = .market
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.appCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct HoldingRow: View {
    let holding: Holding
    /// Live market data; nil when the coin isn't in the current payload.
    let coin: CoinMarketData?
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var marketStore: MarketStore

    private var currentValue: Double {
        // Without a live price, show cost basis (matches how the store
        // values the position in the portfolio total).
        coin.map { holding.amount * $0.currentPrice } ?? holding.totalCost
    }

    private var gainLossPercentage: Double {
        portfolioStore.holdingGainLossPercentage(holding: holding, coins: marketStore.coins)
    }

    var body: some View {
        HStack {
            CoinIconView(
                imageURL: coin?.image ?? holding.imageUrl,
                symbol: holding.symbol,
                size: 45,
                placeholderTint: .gray
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(coin?.name ?? holding.coinName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(Formatters.coinAmount(holding.amount)) \(holding.symbol.uppercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.currency(currentValue))
                    .font(.headline)
                    .foregroundColor(.primary)

                if coin != nil {
                    Text(Formatters.signedPercent(gainLossPercentage))
                        .font(.subheadline)
                        .foregroundColor(gainLossPercentage >= 0 ? .green : .red)
                } else {
                    Text("price unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
