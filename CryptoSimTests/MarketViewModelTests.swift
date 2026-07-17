//
//  MarketViewModelTests.swift
//  CryptoSimTests
//
//  Search + sort presentation logic for the Market tab.
//

import XCTest
@testable import CryptoSim

@MainActor
final class MarketViewModelTests: XCTestCase {
    private var viewModel: MarketViewModel!

    private let bitcoin = makeCoin(id: "bitcoin", symbol: "btc", name: "Bitcoin", currentPrice: 50_000, marketCap: 1_000_000, priceChangePercentage24h: 2.0)
    private let ethereum = makeCoin(id: "ethereum", symbol: "eth", name: "Ethereum", currentPrice: 3_000, marketCap: 500_000, priceChangePercentage24h: -1.5)
    private let dogecoin = makeCoin(id: "dogecoin", symbol: "doge", name: "Dogecoin", currentPrice: 0.1, marketCap: 20_000, priceChangePercentage24h: 5.0)

    private var coins: [CoinMarketData] { [ethereum, dogecoin, bitcoin] }

    override func setUp() {
        viewModel = MarketViewModel()
    }

    // MARK: - Search

    func testEmptyQueryReturnsAllCoins() {
        XCTAssertEqual(viewModel.searchCoins(coins, query: "").count, 3)
        XCTAssertEqual(viewModel.searchCoins(coins, query: "   ").count, 3)
    }

    func testSearchMatchesNameCaseInsensitively() {
        let results = viewModel.searchCoins(coins, query: "BITCOIN")
        XCTAssertEqual(results.map(\.id), ["bitcoin"])
    }

    func testSearchMatchesSymbol() {
        let results = viewModel.searchCoins(coins, query: "eth")
        XCTAssertEqual(results.map(\.id), ["ethereum"])
    }

    func testSearchWithNoMatchesReturnsEmpty() {
        XCTAssertTrue(viewModel.searchCoins(coins, query: "zzz").isEmpty)
    }

    // MARK: - Sort

    func testDefaultSortIsMarketCapDescending() {
        let sorted = viewModel.displayCoins(from: coins)
        XCTAssertEqual(sorted.map(\.id), ["bitcoin", "ethereum", "dogecoin"])
    }

    func testMarketCapAscending() {
        viewModel.sortAscending = true
        let sorted = viewModel.sortCoins(coins)
        XCTAssertEqual(sorted.map(\.id), ["dogecoin", "ethereum", "bitcoin"])
    }

    func testSortByPriceDescending() {
        viewModel.sortOption = .price
        let sorted = viewModel.sortCoins(coins)
        XCTAssertEqual(sorted.map(\.id), ["bitcoin", "ethereum", "dogecoin"])
    }

    func testSortByChangeDescending() {
        viewModel.sortOption = .change
        let sorted = viewModel.sortCoins(coins)
        XCTAssertEqual(sorted.map(\.id), ["dogecoin", "bitcoin", "ethereum"])
    }

    func testSortByNameAscending() {
        viewModel.sortOption = .name
        viewModel.sortAscending = true
        let sorted = viewModel.sortCoins(coins)
        XCTAssertEqual(sorted.map(\.id), ["bitcoin", "dogecoin", "ethereum"])
    }

    /// Regression test for the v1 bug: implementing "ascending" by negating
    /// the comparator breaks strict weak ordering when elements are equal.
    /// With a consistent key-based comparison, equal elements must not crash
    /// or corrupt the sort.
    func testSortIsStableWithEqualKeys() {
        let a = makeCoin(id: "a", name: "A", marketCap: 100)
        let b = makeCoin(id: "b", name: "B", marketCap: 100)
        let c = makeCoin(id: "c", name: "C", marketCap: 100)
        viewModel.sortAscending = true

        let sorted = viewModel.sortCoins([a, b, c])

        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(Set(sorted.map(\.id)), ["a", "b", "c"])
    }

    // MARK: - Combined

    func testDisplayCoinsAppliesSearchThenSort() {
        viewModel.searchText = "coin" // Bitcoin + Dogecoin
        viewModel.sortOption = .price
        let results = viewModel.displayCoins(from: coins)
        XCTAssertEqual(results.map(\.id), ["bitcoin", "dogecoin"])
    }
}
