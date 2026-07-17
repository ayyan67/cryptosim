//
//  PersistedModels.swift
//  CryptoSim
//
//  SwiftData models — the app's on-device source of truth for everything
//  the user owns (holdings, transactions, watchlist, cash). Market prices
//  are deliberately NOT persisted; they're ephemeral API state.
//

import Foundation
import SwiftData

@Model
final class Holding {
    var coinId: String
    var coinName: String
    var symbol: String
    var amount: Double
    var averageBuyPrice: Double
    var imageUrl: String

    init(coinId: String, coinName: String, symbol: String, amount: Double, averageBuyPrice: Double, imageUrl: String = "") {
        self.coinId = coinId
        self.coinName = coinName
        self.symbol = symbol
        self.amount = amount
        self.averageBuyPrice = averageBuyPrice
        self.imageUrl = imageUrl
    }

    /// Cost basis: what was paid for the current position at the
    /// volume-weighted average buy price.
    var totalCost: Double {
        amount * averageBuyPrice
    }
}

/// Buy vs. sell. Stored as a String raw value inside Transaction because
/// SwiftData persists primitives most reliably; the enum is the only API
/// the rest of the app sees (v1 compared raw "BUY"/"SELL" strings).
enum TransactionType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
}

@Model
final class Transaction {
    var id: UUID
    var coinId: String
    var coinName: String
    var symbol: String
    private var typeRawValue: String
    var amount: Double
    var pricePerCoin: Double
    var totalValue: Double
    var timestamp: Date

    init(coinId: String, coinName: String, symbol: String, type: TransactionType, amount: Double, pricePerCoin: Double, timestamp: Date = Date()) {
        self.id = UUID()
        self.coinId = coinId
        self.coinName = coinName
        self.symbol = symbol
        self.typeRawValue = type.rawValue
        self.amount = amount
        self.pricePerCoin = pricePerCoin
        self.totalValue = amount * pricePerCoin
        self.timestamp = timestamp
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .buy }
        set { typeRawValue = newValue.rawValue }
    }

    var formattedAmount: String {
        "\(Formatters.coinAmount(amount)) \(symbol.uppercased())"
    }

    var formattedTotal: String {
        Formatters.currency(totalValue)
    }

    var formattedDate: String {
        Formatters.transactionDate(timestamp)
    }
}

@Model
final class WatchlistItem {
    var coinId: String
    var addedAt: Date

    init(coinId: String) {
        self.coinId = coinId
        self.addedAt = Date()
    }
}

@Model
final class Portfolio {
    var cashBalance: Double
    var initialBalance: Double

    init(cashBalance: Double = 10_000.0, initialBalance: Double = 10_000.0) {
        self.cashBalance = cashBalance
        self.initialBalance = initialBalance
    }
}
