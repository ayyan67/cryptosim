//
//  TradeSheet.swift
//  CryptoSim
//
//  Buy/sell modal. All parsing/validation/execution logic lives in
//  TradeViewModel; this view renders state and forwards user intent.
//

import SwiftUI
import UIKit

struct TradeSheet: View {
    let coin: CoinMarketData
    let side: TradeViewModel.Side

    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var analytics: LocalAnalyticsTracker

    // TradeViewModel needs the injected PortfolioStore and analytics,
    // which aren't available until body runs — so the view model is
    // created in a wrapper view below.
    var body: some View {
        TradeSheetContent(
            viewModel: TradeViewModel(
                coin: coin,
                side: side,
                portfolio: portfolioStore,
                analytics: analytics
            )
        )
    }
}

private struct TradeSheetContent: View {
    @StateObject var viewModel: TradeViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFieldFocused: Bool

    @State private var showError = false
    @State private var showSuccess = false
    @State private var showConfirmation = false

    init(viewModel: TradeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isBuying: Bool { viewModel.side == .buy }
    private var coin: CoinMarketData { viewModel.coin }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                coinHeader

                amountInput

                summary

                Spacer()

                confirmButton
            }
            .background(Color.appBackground)
            .navigationTitle(isBuying ? "Buy \(coin.symbol.uppercased())" : "Sell \(coin.symbol.uppercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFieldFocused = false }
                }
            }
            .alert("Trade Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.lastError?.errorDescription ?? "Something went wrong.")
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("You \(isBuying ? "bought" : "sold") \(Formatters.coinAmount(viewModel.amount ?? 0)) \(coin.symbol.uppercased()) for \(Formatters.currency(viewModel.totalCost))")
            }
            .confirmationDialog(
                isBuying ? "Confirm Purchase" : "Confirm Sale",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button(confirmationLabel) { executeTrade() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Total: \(Formatters.currency(viewModel.totalCost))")
            }
            .onAppear {
                viewModel.trackSheetOpened()
                amountFieldFocused = true
            }
        }
    }

    private var confirmationLabel: String {
        let action = isBuying ? "Buy" : "Sell"
        return "\(action) \(Formatters.coinAmount(viewModel.amount ?? 0)) \(coin.symbol.uppercased())"
    }

    private var coinHeader: some View {
        VStack(spacing: 8) {
            CoinIconView(imageURL: coin.image, symbol: coin.symbol, size: 60)

            Text(coin.name)
                .font(.title2)
                .fontWeight(.bold)

            Text(coin.formattedPrice)
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }

    private var amountInput: some View {
        VStack(spacing: 12) {
            Text(isBuying ? "Amount to Buy" : "Amount to Sell")
                .font(.headline)

            HStack {
                TextField("0.00", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .focused($amountFieldFocused)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(coin.symbol.uppercased())
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(12)

            HStack(spacing: 12) {
                QuickAmountButton(label: "25%") { viewModel.applyQuickFraction(0.25) }
                QuickAmountButton(label: "50%") { viewModel.applyQuickFraction(0.50) }
                QuickAmountButton(label: "75%") { viewModel.applyQuickFraction(0.75) }
                QuickAmountButton(label: "MAX") { viewModel.applyQuickFraction(1.0) }
            }
        }
        .padding(.horizontal)
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Divider()

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(Formatters.currency(viewModel.totalCost))
                    .font(.title2)
                    .fontWeight(.bold)
            }

            if isBuying {
                HStack {
                    Text("Available Cash")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(Formatters.currency(viewModel.availableCash))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("Available to Sell")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Formatters.coinAmount(viewModel.availableToSell)) \(coin.symbol.uppercased())")
                        .foregroundColor(.secondary)
                }
            }

            Divider()
        }
        .padding(.horizontal)
    }

    private var confirmButton: some View {
        Button(action: { showConfirmation = true }) {
            Text(isBuying ? "Buy \(coin.symbol.uppercased())" : "Sell \(coin.symbol.uppercased())")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isValid ? (isBuying ? Color.green : Color.red) : Color.gray)
                .cornerRadius(12)
        }
        .disabled(!viewModel.isValid)
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func executeTrade() {
        if viewModel.execute() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showSuccess = true
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showError = true
        }
    }
}

struct QuickAmountButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(8)
        }
    }
}
