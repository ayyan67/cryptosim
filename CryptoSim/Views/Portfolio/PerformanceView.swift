//
//  PerformanceView.swift
//  CryptoSim
//
//  Performance sheet: overall P&L, portfolio breakdown, and allocation
//  per holding.
//

import SwiftUI

// Pushed from PortfolioView (drill-down content, not a modal task), so it
// renders inside the portfolio tab's NavigationStack.
struct PerformanceView: View {
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore

    private var totalBalance: Double {
        portfolioStore.totalPortfolioValue(coins: marketStore.coins)
    }

    private var totalGainLoss: Double {
        portfolioStore.totalGainLoss(coins: marketStore.coins)
    }

    private var totalGainLossPercentage: Double {
        portfolioStore.totalGainLossPercentage(coins: marketStore.coins)
    }

    private var holdingsValue: Double {
        totalBalance - portfolioStore.cashBalance
    }

    private var holdingsSortedByValue: [Holding] {
        portfolioStore.holdings.sorted { a, b in
            holdingValue(a) > holdingValue(b)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard

                breakdown

                allocation
            }
            .padding(.vertical)
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground)
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            Text("Total Performance")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Text(Formatters.signedCurrency(totalGainLoss))
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(totalGainLoss >= 0 ? .green : .red)

            Text(Formatters.signedPercent(totalGainLossPercentage))
                .font(.title2)
                .foregroundColor(totalGainLoss >= 0 ? .green : .red)

            Text("from \(Formatters.currency(portfolioStore.initialBalance)) initial")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
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

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Portfolio Breakdown")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            HStack(spacing: 12) {
                StatCard(title: "Total Value", value: Formatters.currency(totalBalance), valueColor: .blue)
                StatCard(title: "Cash", value: Formatters.currency(portfolioStore.cashBalance), valueColor: .green)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                StatCard(title: "Invested", value: Formatters.currency(holdingsValue), valueColor: .purple)
                StatCard(title: "# Assets", value: "\(portfolioStore.holdings.count)", valueColor: .orange)
            }
            .padding(.horizontal)
        }
    }

    private var allocation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Allocation")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            if portfolioStore.holdings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No assets yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(Color.appCard)
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ForEach(holdingsSortedByValue, id: \.coinId) { holding in
                    AllocationRow(
                        holding: holding,
                        coin: marketStore.coin(withId: holding.coinId),
                        totalValue: totalBalance
                    )
                }
            }
        }
    }

    private func holdingValue(_ holding: Holding) -> Double {
        portfolioStore.holdingValue(holding: holding, coins: marketStore.coins)
    }
}

struct AllocationRow: View {
    let holding: Holding
    let coin: CoinMarketData?
    let totalValue: Double

    private var holdingValue: Double {
        guard let coin else { return holding.totalCost }
        return holding.amount * coin.currentPrice
    }

    private var percentage: Double {
        guard totalValue > 0 else { return 0 }
        return (holdingValue / totalValue) * 100
    }

    private var gainLoss: Double {
        holdingValue - holding.totalCost
    }

    var body: some View {
        HStack {
            CoinIconView(
                imageURL: coin?.image ?? holding.imageUrl,
                symbol: holding.symbol,
                size: 40,
                placeholderTint: .gray
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(coin?.name ?? holding.coinName)
                    .font(.headline)

                Text("\(String(format: "%.2f", percentage))% of portfolio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.currency(holdingValue))
                    .font(.headline)

                Text(Formatters.signedCurrency(gainLoss))
                    .font(.caption)
                    .foregroundColor(gainLoss >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
