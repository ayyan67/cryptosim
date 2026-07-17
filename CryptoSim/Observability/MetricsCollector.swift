//
//  MetricsCollector.swift
//  CryptoSim
//
//  Session-scoped performance metrics for API traffic: latency percentiles,
//  error rate, and per-endpoint breakdowns. The in-app Metrics dashboard
//  renders this — a miniature version of the service dashboards used to
//  monitor production apps.
//

import Foundation
import Combine

/// One completed (or failed) network request.
struct RequestMetric: Identifiable {
    let id = UUID()
    let endpoint: String       // logical name, e.g. "coins/markets"
    let duration: TimeInterval // seconds
    let statusCode: Int?       // nil when the request never got a response
    let outcome: Outcome
    let timestamp: Date

    enum Outcome: String {
        case success
        case rateLimited = "rate_limited"
        case serverError = "server_error"
        case transportError = "transport_error"
        case decodingError = "decoding_error"
    }

    var isFailure: Bool { outcome != .success }
}

protocol RequestMetricsRecording: AnyObject {
    /// Safe to call from any thread/actor.
    func record(_ metric: RequestMetric)
}

@MainActor
final class MetricsCollector: ObservableObject, RequestMetricsRecording {
    @Published private(set) var requests: [RequestMetric] = []

    private let maxStoredRequests = 500

    nonisolated func record(_ metric: RequestMetric) {
        Task { @MainActor in
            self.requests.append(metric)
            if self.requests.count > self.maxStoredRequests {
                self.requests.removeFirst(self.requests.count - self.maxStoredRequests)
            }
        }
    }

    // MARK: - Aggregates (computed on demand by the dashboard)

    var totalRequests: Int { requests.count }

    var errorRate: Double {
        guard !requests.isEmpty else { return 0 }
        let failures = requests.filter(\.isFailure).count
        return Double(failures) / Double(requests.count)
    }

    var p50Latency: TimeInterval? { latencyPercentile(0.50) }
    var p95Latency: TimeInterval? { latencyPercentile(0.95) }

    func latencyPercentile(_ percentile: Double) -> TimeInterval? {
        let durations = requests.map(\.duration).sorted()
        guard !durations.isEmpty else { return nil }
        let rank = percentile * Double(durations.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        guard upper < durations.count else { return durations.last }
        let weight = rank - Double(lower)
        return durations[lower] * (1 - weight) + durations[upper] * weight
    }

    /// Per-endpoint request count, average latency, and failure count.
    struct EndpointSummary: Identifiable {
        var id: String { endpoint }
        let endpoint: String
        let count: Int
        let averageLatency: TimeInterval
        let failures: Int
    }

    var endpointSummaries: [EndpointSummary] {
        let grouped: [String: [RequestMetric]] = Dictionary(grouping: requests, by: { $0.endpoint })
        var summaries: [EndpointSummary] = []
        for (endpoint, metrics) in grouped {
            let totalLatency: TimeInterval = metrics.reduce(0) { $0 + $1.duration }
            let failures = metrics.filter { $0.isFailure }.count
            summaries.append(EndpointSummary(
                endpoint: endpoint,
                count: metrics.count,
                averageLatency: totalLatency / Double(metrics.count),
                failures: failures
            ))
        }
        return summaries.sorted { $0.count > $1.count }
    }

    func reset() {
        requests = []
    }
}
