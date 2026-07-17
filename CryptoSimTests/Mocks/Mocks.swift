//
//  Mocks.swift
//  CryptoSimTests
//
//  Test doubles and fixture factories shared across the suite.
//

import Foundation
@testable import CryptoSim

// MARK: - Coin fixture factory

/// Builds a CoinMarketData with sensible defaults so tests only specify
/// what they care about.
func makeCoin(
    id: String = "bitcoin",
    symbol: String = "btc",
    name: String = "Bitcoin",
    currentPrice: Double = 50_000,
    marketCap: Double? = 1_000_000_000_000,
    priceChangePercentage24h: Double? = 2.5,
    sparkline: [Double]? = nil
) -> CoinMarketData {
    CoinMarketData(
        id: id,
        symbol: symbol,
        name: name,
        image: "",
        currentPrice: currentPrice,
        marketCap: marketCap,
        marketCapRank: 1,
        totalVolume: 45_000_000_000,
        high24h: currentPrice * 1.02,
        low24h: currentPrice * 0.98,
        priceChange24h: nil,
        priceChangePercentage24h: priceChangePercentage24h,
        circulatingSupply: 19_500_000,
        totalSupply: 21_000_000,
        maxSupply: 21_000_000,
        sparklineIn7d: sparkline.map(SparklineData.init(price:))
    )
}

// MARK: - MarketDataProviding mock

final class MockMarketDataService: MarketDataProviding {
    var coinsToReturn: [CoinMarketData] = []
    var errorToThrow: Error?
    var chartToReturn: [Double] = []
    private(set) var fetchTopCoinsCallCount = 0
    private(set) var fetchChartCallCount = 0

    func fetchTopCoins() async throws -> [CoinMarketData] {
        fetchTopCoinsCallCount += 1
        if let errorToThrow { throw errorToThrow }
        return coinsToReturn
    }

    func fetchPriceChart(coinId: String, days: Int) async throws -> [Double] {
        fetchChartCallCount += 1
        if let errorToThrow { throw errorToThrow }
        return chartToReturn
    }
}

// MARK: - Analytics spy

final class AnalyticsSpy: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []
    private let lock = NSLock()

    func track(_ event: AnalyticsEvent) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    var eventNames: [String] { events.map(\.name) }
}

// MARK: - Metrics spy

final class MetricsSpy: RequestMetricsRecording {
    private(set) var metrics: [RequestMetric] = []
    private let lock = NSLock()

    func record(_ metric: RequestMetric) {
        lock.lock()
        defer { lock.unlock() }
        metrics.append(metric)
    }
}

// MARK: - URLProtocol stub for NetworkClient tests

/// Intercepts URLSession traffic and returns queued responses, so
/// URLSessionNetworkClient's retry/error mapping is testable offline.
final class StubURLProtocol: URLProtocol {
    struct StubResponse {
        let statusCode: Int
        let data: Data
        let error: Error?

        init(statusCode: Int = 200, data: Data = Data(), error: Error? = nil) {
            self.statusCode = statusCode
            self.data = data
            self.error = error
        }
    }

    /// FIFO queue of responses; each request consumes one. The last
    /// response is reused if the queue empties.
    nonisolated(unsafe) static var responseQueue: [StubResponse] = []
    nonisolated(unsafe) static var requestCount = 0
    private static let lock = NSLock()

    static func reset(with responses: [StubResponse]) {
        lock.lock()
        defer { lock.unlock() }
        responseQueue = responses
        requestCount = 0
    }

    private static func nextResponse() -> StubResponse {
        lock.lock()
        defer { lock.unlock() }
        requestCount += 1
        if responseQueue.count > 1 {
            return responseQueue.removeFirst()
        }
        return responseQueue.first ?? StubResponse()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.nextResponse()

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func makeStubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
}
