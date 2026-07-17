//
//  NetworkClient.swift
//  CryptoSim
//
//  Transport layer. `NetworkClient` is a protocol so everything above it is
//  testable without touching the real network; `URLSessionNetworkClient` is
//  the production implementation with:
//    - typed error mapping (429 → rateLimited, 5xx → serverError, ...)
//    - one automatic retry with backoff for transient failures
//    - per-request latency + outcome metrics
//

import Foundation

protocol NetworkClient {
    /// Performs a GET and returns the raw body.
    /// - Parameter endpointName: logical name used for logging/metrics
    ///   (e.g. "coins/markets"), so metrics don't fragment on query params.
    func get(_ url: URL, endpointName: String) async throws -> Data
}

final class URLSessionNetworkClient: NetworkClient {
    private let session: URLSession
    private let metrics: RequestMetricsRecording?
    private let maxRetries: Int
    private let retryDelay: TimeInterval

    init(
        session: URLSession = .shared,
        metrics: RequestMetricsRecording? = nil,
        maxRetries: Int = 1,
        retryDelay: TimeInterval = 0.75
    ) {
        self.session = session
        self.metrics = metrics
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }

    func get(_ url: URL, endpointName: String) async throws -> Data {
        var attempt = 0
        while true {
            do {
                return try await performOnce(url, endpointName: endpointName)
            } catch let error as APIError where error.isTransient && attempt < maxRetries {
                attempt += 1
                AppLog.network.warning(
                    "Retrying \(endpointName, privacy: .public) (attempt \(attempt + 1)) after transient error"
                )
                // Exponential backoff: 0.75s, 1.5s, 3s, ...
                let delay = retryDelay * pow(2, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func performOnce(_ url: URL, endpointName: String) async throws -> Data {
        let start = ContinuousClock.now

        func elapsed() -> TimeInterval {
            let duration = ContinuousClock.now - start
            return Double(duration.components.seconds)
                + Double(duration.components.attoseconds) / 1e18
        }

        func record(_ outcome: RequestMetric.Outcome, statusCode: Int? = nil) {
            metrics?.record(RequestMetric(
                endpoint: endpointName,
                duration: elapsed(),
                statusCode: statusCode,
                outcome: outcome,
                timestamp: Date()
            ))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            record(.transportError)
            AppLog.network.error("Transport error for \(endpointName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw APIError.transportError(description: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            record(.transportError)
            throw APIError.transportError(description: "Non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            record(.success, statusCode: httpResponse.statusCode)
            AppLog.network.debug("\(endpointName, privacy: .public) \(httpResponse.statusCode) in \(String(format: "%.0f", elapsed() * 1000), privacy: .public)ms")
            return data
        case 429:
            record(.rateLimited, statusCode: 429)
            AppLog.network.warning("Rate limited on \(endpointName, privacy: .public)")
            throw APIError.rateLimited
        default:
            record(.serverError, statusCode: httpResponse.statusCode)
            AppLog.network.error("Server error \(httpResponse.statusCode) on \(endpointName, privacy: .public)")
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}
