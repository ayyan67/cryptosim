//
//  TradeViewModelTests.swift
//  CryptoSimTests
//
//  Validation and parsing logic for the trade sheet.
//

import XCTest
import SwiftData
@testable import CryptoSim

@MainActor
final class TradeViewModelTests: XCTestCase {
    private var portfolio: PortfolioStore!
    private var container: ModelContainer!

    override func setUp() async throws {
        let schema = Schema([Holding.self, Transaction.self, WatchlistItem.self, Portfolio.self])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        portfolio = PortfolioStore(modelContext: container.mainContext, analytics: AnalyticsSpy())
    }

    private func makeBuyViewModel(price: Double = 50_000) -> TradeViewModel {
        TradeViewModel(coin: makeCoin(currentPrice: price), side: .buy, portfolio: portfolio)
    }

    // MARK: - Validation

    func testEmptyAmountIsInvalid() {
        let vm = makeBuyViewModel()
        XCTAssertEqual(vm.validationIssue, .emptyAmount)
        XCTAssertFalse(vm.isValid)
    }

    func testGarbageInputIsInvalid() {
        let vm = makeBuyViewModel()
        vm.amountText = "abc"
        XCTAssertEqual(vm.validationIssue, .notANumber)
    }

    func testZeroAndNegativeAreInvalid() {
        let vm = makeBuyViewModel()
        vm.amountText = "0"
        XCTAssertEqual(vm.validationIssue, .nonPositive)
        vm.amountText = "-5"
        XCTAssertEqual(vm.validationIssue, .nonPositive)
    }

    func testBuyExceedingCashIsInvalid() {
        let vm = makeBuyViewModel(price: 50_000)
        vm.amountText = "1" // $50k > $10k cash
        XCTAssertEqual(vm.validationIssue, .exceedsCash)
    }

    func testValidBuyAmountPasses() {
        let vm = makeBuyViewModel(price: 50_000)
        vm.amountText = "0.1" // $5k
        XCTAssertNil(vm.validationIssue)
        XCTAssertTrue(vm.isValid)
        XCTAssertEqual(vm.totalCost, 5_000, accuracy: 0.001)
    }

    func testCommaDecimalSeparatorIsAccepted() {
        // European locale users type "0,1".
        let vm = makeBuyViewModel(price: 50_000)
        vm.amountText = "0,1"
        XCTAssertEqual(vm.amount ?? 0, 0.1, accuracy: 1e-9)
        XCTAssertTrue(vm.isValid)
    }

    func testSellExceedingHoldingsIsInvalid() throws {
        let coin = makeCoin(currentPrice: 50_000)
        try portfolio.buy(coin: coin, amount: 0.05)

        let vm = TradeViewModel(coin: coin, side: .sell, portfolio: portfolio)
        vm.amountText = "0.1"
        XCTAssertEqual(vm.validationIssue, .exceedsHoldings)

        vm.amountText = "0.05"
        XCTAssertNil(vm.validationIssue)
    }

    // MARK: - Quick amounts

    func testQuickFractionFillsFromMaxBuyAmount() {
        let vm = makeBuyViewModel(price: 50_000)
        // Max buy = 10,000 / 50,000 = 0.2; 50% = 0.1
        vm.applyQuickFraction(0.5)
        XCTAssertEqual(vm.amount ?? 0, 0.1, accuracy: 1e-6)
        XCTAssertTrue(vm.isValid)
    }

    func testMaxQuickFractionIsSpendableForBuy() {
        let vm = makeBuyViewModel(price: 61_234.56)
        vm.applyQuickFraction(1.0)
        // The MAX fill must never fail validation.
        XCTAssertTrue(vm.isValid, "MAX quick amount should be executable, got issue: \(String(describing: vm.validationIssue))")
    }

    // MARK: - Execution

    func testExecuteBuySucceedsAndUpdatesPortfolio() {
        let vm = makeBuyViewModel(price: 50_000)
        vm.amountText = "0.1"

        XCTAssertTrue(vm.execute())
        XCTAssertNil(vm.lastError)
        XCTAssertEqual(portfolio.cashBalance, 5_000, accuracy: 0.001)
    }

    func testExecuteInvalidTradeSetsLastError() {
        let vm = makeBuyViewModel()
        vm.amountText = ""

        XCTAssertFalse(vm.execute())
        XCTAssertNotNil(vm.lastError)
    }
}
