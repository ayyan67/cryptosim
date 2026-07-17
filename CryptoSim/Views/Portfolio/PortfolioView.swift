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
    @State private var showingPerformance = false

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
            .refreshable {
                await marketStore.refresh(force: true, source: .pullToRefresh)
            }
            .sheet(isPresented: $showingPerformance) {
                PerformanceView()
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

    private var performanceButton: some View {
        Button(action: { showingPerformance = true }) {
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
                ForEach(portfolioStore.holdings, id: \.coinId) { holding in
                    if let coin = marketStore.coin(withId: holding.coinId) {
                        NavigationLink(destination: HoldingsDetailView(holding: holding, coin: coin)) {
                            HoldingRow(holding: holding, coin: coin)
                        }
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
    let coin: CoinMarketData
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var marketStore: MarketStore

    private var currentValue: Double {
        holding.amount * coin.currentPrice
    }

    private var gainLossPercentage: Double {
        portfolioStore.holdingGainLossPercentage(holding: holding, coins: marketStore.coins)
    }

    var body: some View {
        HStack {
            CoinIconView(imageURL: coin.image, symbol: coin.symbol, size: 45, placeholderTint: .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(coin.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(Formatters.coinAmount(holding.amount)) \(coin.symbol.uppercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.currency(currentValue))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(Formatters.signedPercent(gainLossPercentage))
                    .font(.subheadline)
                    .foregroundColor(gainLossPercentage >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
