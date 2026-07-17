//
//  TradeViewModel.swift
//  CryptoSim
//
//  All the logic behind the trade sheet: amount parsing, validation,
//  quick-percent fills, and trade execution — with zero SwiftUI imports,
//  so every branch is unit-testable.
//

import Foundation
import Combine

@MainActor
final class TradeViewModel: ObservableObject {
    enum Side: String {
        case buy
        case sell
    }

    /// Why the confirm button is disabled (nil means the trade is valid).
    enum ValidationIssue: Equatable {
        case emptyAmount
        case notANumber
        case nonPositive
        case exceedsCash
        case exceedsHoldings
    }

    @Published var amountText = ""
    @Published private(set) var lastError: TradeError?

    let coin: CoinMarketData
    let side: Side

    private let portfolio: PortfolioStore
    private let analytics: AnalyticsTracking

    init(
        coin: CoinMarketData,
        side: Side,
        portfolio: PortfolioStore,
        analytics: AnalyticsTracking = NoOpAnalyticsTracker()
    ) {
        self.coin = coin
        self.side = side
        self.portfolio = portfolio
        self.analytics = analytics
    }

    // MARK: - Derived values

    var amount: Double? {
        Formatters.parseAmount(amountText)
    }

    var totalCost: Double {
        (amount ?? 0) * coin.currentPrice
    }

    /// The most the user could trade right now.
    var maxAmount: Double {
        switch side {
        case .buy:
            guard coin.currentPrice > 0 else { return 0 }
            return portfolio.cashBalance / coin.currentPrice
        case .sell:
            return portfolio.holdingAmount(for: coin.id)
        }
    }

    var availableCash: Double { portfolio.cashBalance }
    var availableToSell: Double { portfolio.holdingAmount(for: coin.id) }

    var validationIssue: ValidationIssue? {
        if amountText.trimmingCharacters(in: .whitespaces).isEmpty { return .emptyAmount }
        guard let amount else { return .notANumber }
        if amount <= 0 { return .nonPositive }
        switch side {
        case .buy:
            if totalCost > portfolio.cashBalance { return .exceedsCash }
        case .sell:
            if amount > availableToSell { return .exceedsHoldings }
        }
        return nil
    }

    var isValid: Bool { validationIssue == nil }

    // MARK: - Actions

    /// Fills the amount field with a fraction (25% / 50% / 75% / 100%) of
    /// the maximum tradable amount.
    func applyQuickFraction(_ fraction: Double) {
        amountText = Formatters.coinAmount(maxAmount * fraction)
    }

    /// Executes the trade. Returns true on success so the view can show
    /// the confirmation state; on failure `lastError` carries the reason.
    func execute() -> Bool {
        guard let amount, isValid else {
            lastError = .invalidAmount
            return false
        }
        do {
            switch side {
            case .buy:
                try portfolio.buy(coin: coin, amount: amount)
            case .sell:
                try portfolio.sell(coin: coin, amount: amount)
            }
            lastError = nil
            return true
        } catch let error as TradeError {
            lastError = error
            return false
        } catch {
            lastError = .storageUnavailable
            return false
        }
    }

    func trackSheetOpened() {
        analytics.track(.tradeSheetOpened(coinId: coin.id, side: side.rawValue))
    }
}
