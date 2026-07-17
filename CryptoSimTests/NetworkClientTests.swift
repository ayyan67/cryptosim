//
//  NetworkClientTests.swift
//  CryptoSimTests
//
//  URLSessionNetworkClient behavior via a stubbed URLProtocol: status-code
//  mapping, retry-on-transient-failure, no-retry-on-429, and metrics
//  emission. No real network involved.
//

import XCTest
@testable import CryptoSim

final class NetworkClientTests: XCTestCase {
    private let testURL = URL(string: "https://api.coingecko.com/api/v3/test")!

    private func makeClient(metrics: MetricsSpy? = nil, maxRetries: Int = 1) -> URLSessionNetworkClient {
        URLSessionNetworkClient(
            session: makeStubbedSession(),
            metrics: metrics,
            maxRetries: maxRetries,
            retryDelay: 0.01 // keep tests fast
        )
    }

    func testSuccessReturnsData() async throws {
        StubURLProtocol.reset(with: [.init(statusCode: 200, data: Data("hello".utf8))])

        let data = try await makeClient().get(testURL, endpointName: "test")

        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testRateLimitThrowsWithoutRetry() async {
        StubURLProtocol.reset(with: [.init(statusCode: 429)])

        do {
            _ = try await makeClient().get(testURL, endpointName: "test")
            XCTFail("Expected rateLimited error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
        // 429 is not transient — hammering a rate-limited API makes it worse.
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testServerErrorRetriesOnceThenSucceeds() async throws {
        StubURLProtocol.reset(with: [
            .init(statusCode: 503),
            .init(statusCode: 200, data: Data("recovered".utf8))
        ])

        let data = try await makeClient().get(testURL, endpointName: "test")

        XCTAssertEqual(String(data: data, encoding: .utf8), "recovered")
        XCTAssertEqual(StubURLProtocol.requestCount, 2)
    }

    func testExhaustedRetriesThrowServerError() async {
        StubURLProtocol.reset(with: [.init(statusCode: 500)])

        do {
            _ = try await makeClient(maxRetries: 1).get(testURL, endpointName: "test")
            XCTFail("Expected serverError")
        } catch {
            XCTAssertEqual(error as? APIError, .serverError(statusCode: 500))
        }
        XCTAssertEqual(StubURLProtocol.requestCount, 2) // initial + 1 retry
    }

    func testClientErrorDoesNotRetry() async {
        StubURLProtocol.reset(with: [.init(statusCode: 404)])

        do {
            _ = try await makeClient().get(testURL, endpointName: "test")
            XCTFail("Expected serverError(404)")
        } catch {
            XCTAssertEqual(error as? APIError, .serverError(statusCode: 404))
        }
        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    func testTransportErrorIsMappedAndRetried() async {
        StubURLProtocol.reset(with: [
            .init(error: URLError(.notConnectedToInternet)),
            .init(statusCode: 200, data: Data("back online".utf8))
        ])

        do {
            let data = try await makeClient().get(testURL, endpointName: "test")
            XCTAssertEqual(String(data: data, encoding: .utf8), "back online")
        } catch {
            XCTFail("Retry should have recovered, got \(error)")
        }
    }

    func testMetricsAreRecordedForEachAttempt() async throws {
        let spy = MetricsSpy()
        StubURLProtocol.reset(with: [
            .init(statusCode: 503),
            .init(statusCode: 200)
        ])

        _ = try await makeClient(metrics: spy).get(testURL, endpointName: "test")

        XCTAssertEqual(spy.metrics.count, 2)
        XCTAssertEqual(spy.metrics[0].outcome, .serverError)
        XCTAssertEqual(spy.metrics[1].outcome, .success)
        XCTAssertEqual(spy.metrics[0].endpoint, "test")
    }
}
