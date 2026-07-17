//
//  MarketStoreTests.swift
//  CryptoSimTests
//
//  Refresh lifecycle: load states, TTL caching, stale-data fallback.
//

import XCTest
@testable import CryptoSim

@MainActor
final class MarketStoreTests: XCTestCase {
    private var service: MockMarketDataService!
    private var analytics: AnalyticsSpy!
    private var store: MarketStore!

    override func setUp() {
        service = MockMarketDataService()
        analytics = AnalyticsSpy()
        store = MarketStore(service: service, analytics: analytics, cacheTTL: 30)
    }

    func testSuccessfulRefreshLoadsCoins() async {
        service.coinsToReturn = [makeCoin()]

        await store.refresh(source: .appLaunch)

        XCTAssertEqual(store.coins.count, 1)
        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertNotNil(store.lastUpdated)
        XCTAssertTrue(analytics.eventNames.contains("market_refreshed"))
    }

    func testRefreshWithinTTLIsSkipped() async {
        service.coinsToReturn = [makeCoin()]

        await store.refresh(source: .appLaunch)
        await store.refresh(source: .appLaunch) // within TTL, not forced

        XCTAssertEqual(service.fetchTopCoinsCallCount, 1)
    }

    func testForcedRefreshBypassesTTL() async {
        service.coinsToReturn = [makeCoin()]

        await store.refresh(source: .appLaunch)
        await store.refresh(force: true, source: .pullToRefresh)

        XCTAssertEqual(service.fetchTopCoinsCallCount, 2)
    }

    func testFailureKeepsStaleCoinsAndExposesError() async {
        service.coinsToReturn = [makeCoin()]
        await store.refresh(source: .appLaunch)

        service.errorToThrow = APIError.rateLimited
        await store.refresh(force: true, source: .autoTimer)

        // Stale data preserved for the UI; error surfaced alongside it.
        XCTAssertEqual(store.coins.count, 1)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(analytics.eventNames.contains("market_refresh_failed"))
    }

    func testInitialFailureProducesFailedStateWithNoCoins() async {
        service.errorToThrow = APIError.transportError(description: "offline")

        await store.refresh(source: .appLaunch)

        XCTAssertTrue(store.coins.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }

    func testCoinLookupById() async {
        service.coinsToReturn = [makeCoin(id: "bitcoin"), makeCoin(id: "ethereum")]
        await store.refresh(source: .appLaunch)

        XCTAssertEqual(store.coin(withId: "ethereum")?.id, "ethereum")
        XCTAssertNil(store.coin(withId: "dogecoin"))
    }

    // MARK: - Auto-refresh lifecycle

    func testAutoRefreshTimerTriggersRefresh() async throws {
        service.coinsToReturn = [makeCoin()]
        store.startAutoRefresh(interval: 0.05)
        defer { store.stopAutoRefresh() }

        // Give the timer a few ticks' worth of time.
        let deadline = Date().addingTimeInterval(2)
        while service.fetchTopCoinsCallCount == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertGreaterThanOrEqual(service.fetchTopCoinsCallCount, 1)
    }

    func testForegroundingTriggersRefresh() async {
        service.coinsToReturn = [makeCoin()]

        store.setSceneActive(false)
        store.setSceneActive(true)
        // Let the fire-and-forget refresh Task run.
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(service.fetchTopCoinsCallCount, 1)
    }

    func testRedundantActivationDoesNotRefresh() async {
        service.coinsToReturn = [makeCoin()]

        // Scene starts active; re-asserting active must not refresh.
        store.setSceneActive(true)
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(service.fetchTopCoinsCallCount, 0)
    }
}
