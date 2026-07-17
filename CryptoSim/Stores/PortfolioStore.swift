//
//  PortfolioStore.swift
//  CryptoSim
//
//  Owns everything the user has: cash, holdings, transactions, watchlist.
//  Backed by SwiftData; all mutations go through here so trade invariants
//  (cash never negative, holdings never oversold, average cost correct)
//  live in exactly one place — and that place is unit-tested.
//
//  v1 equivalent: PortfolioManager, whose buy/sell returned Bool and
//  swallowed persistence errors with `try?`. v2 throws typed TradeErrors
//  and logs persistence failures.
//

import Foundation
import SwiftData
import Combine

enum TradeError: Error, Equatable {
    case invalidAmount
    case insufficientFunds(needed: Double, available: Double)
    case insufficientHoldings(requested: Double, available: Double)
    case storageUnavailable
}

extension TradeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Enter an amount greater than zero."
        case .insufficientFunds(let needed, let available):
            return "This costs \(Formatters.currency(needed)) but you only have \(Formatters.currency(available)) in cash."
        case .insufficientHoldings(let requested, let available):
            return "You tried to sell \(Formatters.coinAmount(requested)) but only hold \(Formatters.coinAmount(available))."
        case .storageUnavailable:
            return "Couldn't access local storage. Please restart the app."
        }
    }

    /// Short machine-readable reason for analytics.
    var analyticsReason: String {
        switch self {
        case .invalidAmount: return "invalid_amount"
        case .insufficientFunds: return "insufficient_funds"
        case .insufficientHoldings: return "insufficient_holdings"
        case .storageUnavailable: return "storage_unavailable"
        }
    }
}

@MainActor
final class PortfolioStore: ObservableObject {
    @Published private(set) var holdings: [Holding] = []
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var watchlistItems: [WatchlistItem] = []
    @Published private(set) var cashBalance: Double = PortfolioStore.startingBalance
    @Published private(set) var initialBalance: Double = PortfolioStore.startingBalance

    static let startingBalance = 10_000.0

    /// Positions smaller than this are treated as fully sold and removed
    /// (avoids dust rows like 0.000000004 BTC from floating-point math).
    static let dustThreshold = 1e-8

    private let modelContext: ModelContext
    private let analytics: AnalyticsTracking

    /// The single persisted Portfolio row (cash + initial balance),
    /// loaded once so cash updates don't re-fetch it on every trade.
    private var portfolioModel: Portfolio?

    init(modelContext: ModelContext, analytics: AnalyticsTracking) {
        self.modelContext = modelContext
        self.analytics = analytics
        loadData()
    }

    // MARK: - Loading

    private func loadData() {
        do {
            holdings = try modelContext.fetch(FetchDescriptor<Holding>())

            var transactionDescriptor = FetchDescriptor<Transaction>()
            transactionDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            transactions = try modelContext.fetch(transactionDescriptor)

            var watchlistDescriptor = FetchDescriptor<WatchlistItem>()
            watchlistDescriptor.sortBy = [SortDescriptor(\.addedAt)]
            watchlistItems = try modelContext.fetch(watchlistDescriptor)

            if let portfolio = try modelContext.fetch(FetchDescriptor<Portfolio>()).first {
                portfolioModel = portfolio
            } else {
                let newPortfolio = Portfolio()
                modelContext.insert(newPortfolio)
                portfolioModel = newPortfolio
                save(context: "create initial portfolio")
            }
            cashBalance = portfolioModel?.cashBalance ?? PortfolioStore.startingBalance
            initialBalance = portfolioModel?.initialBalance ?? PortfolioStore.startingBalance
            AppLog.persistence.info("Loaded \(self.holdings.count) holdings, \(self.transactions.count) transactions")
        } catch {
            AppLog.persistence.error("Failed to load portfolio data: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Valuation

    func totalPortfolioValue(coins: [CoinMarketData]) -> Double {
        var total = cashBalance
        for holding in holdings {
            if let coin = coins.first(where: { $0.id == holding.coinId }) {
                total += holding.amount * coin.currentPrice
            } else {
                // No live price — fall back to cost basis rather than
                // silently valuing the position at zero.
                total += holding.totalCost
            }
        }
        return total
    }

    func totalGainLoss(coins: [CoinMarketData]) -> Double {
        totalPortfolioValue(coins: coins) - initialBalance
    }

    func totalGainLossPercentage(coins: [CoinMarketData]) -> Double {
        guard initialBalance > 0 else { return 0 }
        return (totalGainLoss(coins: coins) / initialBalance) * 100
    }

    func holdingValue(holding: Holding, coins: [CoinMarketData]) -> Double {
        if let coin = coins.first(where: { $0.id == holding.coinId }) {
            return holding.amount * coin.currentPrice
        }
        return holding.totalCost
    }

    func holdingGainLoss(holding: Holding, coins: [CoinMarketData]) -> Double {
        holdingValue(holding: holding, coins: coins) - holding.totalCost
    }

    func holdingGainLossPercentage(holding: Holding, coins: [CoinMarketData]) -> Double {
        let costBasis = holding.totalCost
        guard costBasis > 0 else { return 0 }
        return (holdingGainLoss(holding: holding, coins: coins) / costBasis) * 100
    }

    // MARK: - Trading

    /// Buys `amount` of `coin` at its current price.
    /// Maintains the volume-weighted average buy price on the holding.
    func buy(coin: CoinMarketData, amount: Double) throws {
        guard amount > 0, amount.isFinite else { throw TradeError.invalidAmount }

        let totalCost = amount * coin.currentPrice
        guard cashBalance >= totalCost else {
            let error = TradeError.insufficientFunds(needed: totalCost, available: cashBalance)
            analytics.track(.tradeFailed(coinId: coin.id, side: "buy", reason: error.analyticsReason))
            throw error
        }

        cashBalance -= totalCost
        persistCashBalance()

        if let existing = holdings.first(where: { $0.coinId == coin.id }) {
            let newTotalAmount = existing.amount + amount
            let newTotalCost = existing.totalCost + totalCost
            existing.averageBuyPrice = newTotalCost / newTotalAmount
            existing.amount = newTotalAmount
        } else {
            let newHolding = Holding(
                coinId: coin.id,
                coinName: coin.name,
                symbol: coin.symbol,
                amount: amount,
                averageBuyPrice: coin.currentPrice,
                imageUrl: coin.image
            )
            modelContext.insert(newHolding)
            holdings.append(newHolding)
        }

        recordTransaction(coin: coin, type: .buy, amount: amount)
        save(context: "buy \(coin.id)")

        analytics.track(.tradeExecuted(coinId: coin.id, side: "buy", amount: amount, totalValue: totalCost))
        AppLog.trading.info("BUY \(amount) \(coin.symbol, privacy: .public) for \(totalCost)")
    }

    /// Sells `amount` of `coin` at its current price. Positions that fall
    /// below the dust threshold are removed entirely.
    func sell(coin: CoinMarketData, amount: Double) throws {
        guard amount > 0, amount.isFinite else { throw TradeError.invalidAmount }

        guard let holding = holdings.first(where: { $0.coinId == coin.id }),
              holding.amount >= amount else {
            let available = holdings.first(where: { $0.coinId == coin.id })?.amount ?? 0
            let error = TradeError.insufficientHoldings(requested: amount, available: available)
            analytics.track(.tradeFailed(coinId: coin.id, side: "sell", reason: error.analyticsReason))
            throw error
        }

        let totalValue = amount * coin.currentPrice
        cashBalance += totalValue
        persistCashBalance()

        holding.amount -= amount
        if holding.amount <= Self.dustThreshold {
            modelContext.delete(holding)
            holdings.removeAll { $0.coinId == coin.id }
        }

        recordTransaction(coin: coin, type: .sell, amount: amount)
        save(context: "sell \(coin.id)")

        analytics.track(.tradeExecuted(coinId: coin.id, side: "sell", amount: amount, totalValue: totalValue))
        AppLog.trading.info("SELL \(amount) \(coin.symbol, privacy: .public) for \(totalValue)")
    }

    private func recordTransaction(coin: CoinMarketData, type: TransactionType, amount: Double) {
        let transaction = Transaction(
            coinId: coin.id,
            coinName: coin.name,
            symbol: coin.symbol,
            type: type,
            amount: amount,
            pricePerCoin: coin.currentPrice
        )
        modelContext.insert(transaction)
        transactions.insert(transaction, at: 0)
    }

    private func persistCashBalance() {
        portfolioModel?.cashBalance = cashBalance
    }

    // MARK: - Reset

    /// Wipes holdings and history and restores the starting cash balance.
    /// The watchlist is deliberately kept — it's a preference, not a position.
    func resetPortfolio() {
        for holding in holdings { modelContext.delete(holding) }
        holdings = []

        for transaction in transactions { modelContext.delete(transaction) }
        transactions = []

        cashBalance = PortfolioStore.startingBalance
        initialBalance = PortfolioStore.startingBalance
        portfolioModel?.cashBalance = cashBalance
        portfolioModel?.initialBalance = initialBalance

        save(context: "reset portfolio")
        analytics.track(.portfolioReset)
        AppLog.trading.info("Portfolio reset to \(PortfolioStore.startingBalance)")
    }

    // MARK: - Watchlist

    func isInWatchlist(coinId: String) -> Bool {
        watchlistItems.contains { $0.coinId == coinId }
    }

    func addToWatchlist(coin: CoinMarketData) {
        guard !isInWatchlist(coinId: coin.id) else { return }
        let item = WatchlistItem(
            coinId: coin.id,
            coinName: coin.name,
            symbol: coin.symbol,
            imageUrl: coin.image
        )
        modelContext.insert(item)
        watchlistItems.append(item)
        save(context: "watchlist add \(coin.id)")
        analytics.track(.watchlistAdded(coinId: coin.id))
    }

    func removeFromWatchlist(coinId: String) {
        guard let item = watchlistItems.first(where: { $0.coinId == coinId }) else { return }
        modelContext.delete(item)
        watchlistItems.removeAll { $0.coinId == coinId }
        save(context: "watchlist remove \(coinId)")
        analytics.track(.watchlistRemoved(coinId: coinId))
    }

    func toggleWatchlist(coin: CoinMarketData) {
        if isInWatchlist(coinId: coin.id) {
            removeFromWatchlist(coinId: coin.id)
        } else {
            addToWatchlist(coin: coin)
        }
    }

    // MARK: - Holdings lookup

    func holding(for coinId: String) -> Holding? {
        holdings.first { $0.coinId == coinId }
    }

    func hasHolding(for coinId: String) -> Bool {
        holdings.contains { $0.coinId == coinId && $0.amount > 0 }
    }

    func holdingAmount(for coinId: String) -> Double {
        holding(for: coinId)?.amount ?? 0
    }

    // MARK: - Persistence

    private func save(context operation: String) {
        do {
            try modelContext.save()
        } catch {
            // Don't crash on a save failure — log it loudly. SwiftData
            // keeps in-memory state consistent, so the app remains usable.
            AppLog.persistence.error("Save failed during \(operation, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
