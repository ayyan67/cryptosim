//
//  PortfolioStoreTests.swift
//  CryptoSimTests
//
//  The money math. Every trade invariant lives in PortfolioStore, so this
//  suite covers: average-cost basis, cash conservation, oversell/overspend
//  rejection, dust cleanup, transaction recording, and watchlist behavior.
//  Uses an in-memory SwiftData container per test — fast and isolated.
//

import XCTest
import SwiftData
@testable import CryptoSim

@MainActor
final class PortfolioStoreTests: XCTestCase {
    private var store: PortfolioStore!
    private var analytics: AnalyticsSpy!
    private var container: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([Holding.self, Transaction.self, WatchlistItem.self, Portfolio.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        analytics = AnalyticsSpy()
        store = PortfolioStore(modelContext: container.mainContext, analytics: analytics)
    }

    override func tearDown() {
        store = nil
        analytics = nil
        container = nil
    }

    // MARK: - Initial state

    func testStartsWithTenThousandCash() {
        XCTAssertEqual(store.cashBalance, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.initialBalance, 10_000, accuracy: 0.001)
        XCTAssertTrue(store.holdings.isEmpty)
        XCTAssertTrue(store.transactions.isEmpty)
    }

    // MARK: - Buying

    func testBuyDeductsCashAndCreatesHolding() throws {
        let coin = makeCoin(currentPrice: 50_000)

        try store.buy(coin: coin, amount: 0.1)

        XCTAssertEqual(store.cashBalance, 5_000, accuracy: 0.001)
        XCTAssertEqual(store.holdings.count, 1)
        XCTAssertEqual(store.holdings[0].amount, 0.1, accuracy: 1e-9)
        XCTAssertEqual(store.holdings[0].averageBuyPrice, 50_000, accuracy: 0.001)
    }

    func testBuyRecordsTransaction() throws {
        let coin = makeCoin(currentPrice: 50_000)

        try store.buy(coin: coin, amount: 0.1)

        XCTAssertEqual(store.transactions.count, 1)
        XCTAssertEqual(store.transactions[0].type, .buy)
        XCTAssertEqual(store.transactions[0].totalValue, 5_000, accuracy: 0.001)
    }

    func testBuyingTwiceComputesVolumeWeightedAverageCost() throws {
        // 0.05 BTC @ $50k ($2,500), then 0.05 BTC @ $60k ($3,000)
        // → avg $55k over 0.1 BTC.
        try store.buy(coin: makeCoin(currentPrice: 50_000), amount: 0.05)
        try store.buy(coin: makeCoin(currentPrice: 60_000), amount: 0.05)

        XCTAssertEqual(store.holdings.count, 1)
        XCTAssertEqual(store.holdings[0].amount, 0.1, accuracy: 1e-9)
        XCTAssertEqual(store.holdings[0].averageBuyPrice, 55_000, accuracy: 0.001)
        XCTAssertEqual(store.cashBalance, 10_000 - 2_500 - 3_000, accuracy: 0.001)
    }

    func testBuyRejectsInsufficientFunds() {
        let coin = makeCoin(currentPrice: 50_000)

        XCTAssertThrowsError(try store.buy(coin: coin, amount: 1.0)) { error in
            guard case TradeError.insufficientFunds = error else {
                return XCTFail("Expected insufficientFunds, got \(error)")
            }
        }
        // Nothing should have changed.
        XCTAssertEqual(store.cashBalance, 10_000, accuracy: 0.001)
        XCTAssertTrue(store.holdings.isEmpty)
        XCTAssertTrue(store.transactions.isEmpty)
    }

    func testBuyRejectsZeroNegativeAndNonFiniteAmounts() {
        let coin = makeCoin()
        XCTAssertThrowsError(try store.buy(coin: coin, amount: 0))
        XCTAssertThrowsError(try store.buy(coin: coin, amount: -1))
        XCTAssertThrowsError(try store.buy(coin: coin, amount: .nan))
        XCTAssertThrowsError(try store.buy(coin: coin, amount: .infinity))
    }

    // MARK: - Selling

    func testSellAddsCashAndReducesHolding() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try store.buy(coin: coin, amount: 0.1)

        try store.sell(coin: coin, amount: 0.05)

        XCTAssertEqual(store.cashBalance, 5_000 + 2_500, accuracy: 0.001)
        XCTAssertEqual(store.holdings[0].amount, 0.05, accuracy: 1e-9)
    }

    func testSellingEntirePositionRemovesHolding() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try store.buy(coin: coin, amount: 0.1)

        try store.sell(coin: coin, amount: 0.1)

        XCTAssertTrue(store.holdings.isEmpty, "Fully sold position should be removed, not left at 0")
        XCTAssertEqual(store.cashBalance, 10_000, accuracy: 0.001)
    }

    func testSellAtHigherPriceRealizesProfit() throws {
        try store.buy(coin: makeCoin(currentPrice: 50_000), amount: 0.1)   // -5,000
        try store.sell(coin: makeCoin(currentPrice: 60_000), amount: 0.1)  // +6,000

        XCTAssertEqual(store.cashBalance, 11_000, accuracy: 0.001)
    }

    func testSellRejectsOverselling() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try store.buy(coin: coin, amount: 0.1)

        XCTAssertThrowsError(try store.sell(coin: coin, amount: 0.2)) { error in
            guard case TradeError.insufficientHoldings = error else {
                return XCTFail("Expected insufficientHoldings, got \(error)")
            }
        }
        XCTAssertEqual(store.holdings[0].amount, 0.1, accuracy: 1e-9)
    }

    func testSellRejectsCoinNeverOwned() {
        XCTAssertThrowsError(try store.sell(coin: makeCoin(id: "dogecoin"), amount: 1)) { error in
            guard case TradeError.insufficientHoldings = error else {
                return XCTFail("Expected insufficientHoldings, got \(error)")
            }
        }
    }

    func testDustPositionIsRemovedAfterSell() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try store.buy(coin: coin, amount: 0.1)

        // Sell everything except a sliver below the dust threshold.
        try store.sell(coin: coin, amount: 0.1 - 1e-9)

        XCTAssertTrue(store.holdings.isEmpty, "Sub-dust remainder should be cleaned up")
    }

    // MARK: - Valuation

    func testTotalPortfolioValueUsesLivePrices() throws {
        try store.buy(coin: makeCoin(currentPrice: 50_000), amount: 0.1)

        // Price doubles.
        let value = store.totalPortfolioValue(coins: [makeCoin(currentPrice: 100_000)])

        XCTAssertEqual(value, 5_000 + 10_000, accuracy: 0.001)
        XCTAssertEqual(store.totalGainLoss(coins: [makeCoin(currentPrice: 100_000)]), 5_000, accuracy: 0.001)
    }

    func testPortfolioValueFallsBackToCostBasisWhenPriceMissing() throws {
        try store.buy(coin: makeCoin(currentPrice: 50_000), amount: 0.1)

        // No live price available at all → position valued at cost, not zero.
        let value = store.totalPortfolioValue(coins: [])

        XCTAssertEqual(value, 10_000, accuracy: 0.001)
    }

    func testHoldingGainLossPercentage() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try store.buy(coin: coin, amount: 0.1)

        let pct = store.holdingGainLossPercentage(
            holding: store.holdings[0],
            coins: [makeCoin(currentPrice: 55_000)]
        )

        XCTAssertEqual(pct, 10.0, accuracy: 0.001)
    }

    // MARK: - Watchlist

    func testWatchlistAddRemoveAndToggle() {
        XCTAssertFalse(store.isInWatchlist(coinId: "bitcoin"))

        store.addToWatchlist(coinId: "bitcoin")
        XCTAssertTrue(store.isInWatchlist(coinId: "bitcoin"))

        // Duplicate adds are ignored.
        store.addToWatchlist(coinId: "bitcoin")
        XCTAssertEqual(store.watchlistItems.count, 1)

        store.toggleWatchlist(coinId: "bitcoin")
        XCTAssertFalse(store.isInWatchlist(coinId: "bitcoin"))
    }

    // MARK: - Persistence round-trip

    func testStateSurvivesStoreReload() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try store.buy(coin: coin, amount: 0.1)
        store.addToWatchlist(coinId: "ethereum")

        // New store instance over the same container = app relaunch.
        let reloaded = PortfolioStore(modelContext: container.mainContext, analytics: AnalyticsSpy())

        XCTAssertEqual(reloaded.cashBalance, 5_000, accuracy: 0.001)
        XCTAssertEqual(reloaded.holdings.count, 1)
        XCTAssertEqual(reloaded.transactions.count, 1)
        XCTAssertTrue(reloaded.isInWatchlist(coinId: "ethereum"))
    }

    // MARK: - Analytics

    func testTradeEmitsAnalyticsEvents() throws {
        try store.buy(coin: makeCoin(), amount: 0.01)
        XCTAssertTrue(analytics.eventNames.contains("trade_executed"))

        XCTAssertThrowsError(try store.sell(coin: makeCoin(id: "unknown"), amount: 1))
        XCTAssertTrue(analytics.eventNames.contains("trade_failed"))
    }
}
