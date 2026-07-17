//
//  HoldingsDetailView.swift
//  CryptoSim
//
//  Position detail for a coin the user holds: value, P&L, stats, chart,
//  and buy-more/sell actions.
//

import SwiftUI

struct HoldingsDetailView: View {
    let holding: Holding
    let coin: CoinMarketData
    @EnvironmentObject var marketStore: MarketStore
    @EnvironmentObject var portfolioStore: PortfolioStore

    @State private var showingBuySheet = false
    @State private var showingSellSheet = false

    private var currentValue: Double {
        holding.amount * coin.currentPrice
    }

    private var gainLoss: Double {
        portfolioStore.holdingGainLoss(holding: holding, coins: marketStore.coins)
    }

    private var gainLossPercentage: Double {
        portfolioStore.holdingGainLossPercentage(holding: holding, coins: marketStore.coins)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard

                statsGrid

                chartSection

                actionButtons
            }
            .padding(.vertical)
        }
        .navigationTitle("\(coin.name) Holdings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground)
        .sheet(isPresented: $showingBuySheet) {
            TradeSheet(coin: coin, side: .buy)
        }
        .sheet(isPresented: $showingSellSheet) {
            TradeSheet(coin: coin, side: .sell)
        }
    }

    private var headerCard: some View {
        VStack(spacing: 15) {
            CoinIconView(imageURL: coin.image, symbol: coin.symbol, size: 80, placeholderTint: .purple)

            Text(coin.name)
                .font(.title)
                .fontWeight(.bold)

            Text(coin.symbol.uppercased())
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Text(Formatters.currency(currentValue))
                .font(.system(size: 36, weight: .bold))

            Text("\(Formatters.coinAmount(holding.amount)) \(coin.symbol.uppercased())")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
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

    private var statsGrid: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                StatCard(title: "Current Price", value: coin.formattedPrice)
                StatCard(
                    title: "24h Change",
                    value: coin.formattedChange,
                    valueColor: coin.priceChangeIsPositive ? .green : .red
                )
            }

            HStack(spacing: 15) {
                StatCard(
                    title: "Your Holdings",
                    value: "\(Formatters.coinAmount(holding.amount)) \(coin.symbol.uppercased())"
                )
                StatCard(
                    title: "Total P&L",
                    value: Formatters.signedCurrency(gainLoss),
                    valueColor: gainLoss >= 0 ? .green : .red
                )
            }

            HStack(spacing: 15) {
                StatCard(
                    title: "Avg Buy Price",
                    value: Formatters.currency(holding.averageBuyPrice)
                )
                StatCard(
                    title: "P&L %",
                    value: Formatters.signedPercent(gainLossPercentage),
                    valueColor: gainLossPercentage >= 0 ? .green : .red
                )
            }
        }
        .padding(.horizontal)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Price Chart (Last 7 Days)")
                .font(.headline)
                .padding(.horizontal)

            ChartView(
                data: coin.sparklineIn7d?.price ?? [],
                isPositive: coin.priceChangeIsPositive
            )
            .frame(height: 200)
            .padding(.horizontal)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showingBuySheet = true }) {
                Text("Buy More")
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
                    .background(Color.red)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}
