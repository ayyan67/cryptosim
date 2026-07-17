//
//  MetricsDashboardView.swift
//  CryptoSim
//
//  In-app observability dashboard (DEBUG builds only): API latency
//  percentiles, error rate, per-endpoint breakdown, and the live analytics
//  event stream. A pocket-sized version of the service dashboards teams
//  use to watch production health — useful here for demoing instrumentation
//  and for debugging rate-limit behavior against the free CoinGecko tier.
//

import SwiftUI

struct MetricsDashboardView: View {
    @EnvironmentObject var metrics: MetricsCollector
    @EnvironmentObject var analytics: LocalAnalyticsTracker

    var body: some View {
        NavigationStack {
            List {
                networkSection
                endpointSection
                analyticsCountsSection
                eventStreamSection
            }
            .navigationTitle("Metrics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        metrics.reset()
                        analytics.resetLifetimeCounts()
                    }
                }
            }
        }
    }

    // MARK: - Network health

    private var networkSection: some View {
        Section("Network (this session)") {
            LabeledContent("Requests", value: "\(metrics.totalRequests)")
            LabeledContent("Error rate", value: String(format: "%.1f%%", metrics.errorRate * 100))
            LabeledContent("p50 latency", value: formatLatency(metrics.p50Latency))
            LabeledContent("p95 latency", value: formatLatency(metrics.p95Latency))
        }
    }

    private var endpointSection: some View {
        Section("By endpoint") {
            if metrics.endpointSummaries.isEmpty {
                Text("No requests yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(metrics.endpointSummaries) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.endpoint)
                            .font(.headline)
                        HStack {
                            Text("\(summary.count) requests")
                            Text("avg \(formatLatency(summary.averageLatency))")
                            if summary.failures > 0 {
                                Text("\(summary.failures) failed")
                                    .foregroundColor(.red)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Analytics

    private var analyticsCountsSection: some View {
        Section("Event counts (lifetime)") {
            if analytics.lifetimeCounts.isEmpty {
                Text("No events yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(analytics.lifetimeCounts.sorted { $0.value > $1.value }, id: \.key) { name, count in
                    LabeledContent(name, value: "\(count)")
                }
            }
        }
    }

    private var eventStreamSection: some View {
        Section("Live event stream (newest first)") {
            if analytics.recentEvents.isEmpty {
                Text("No events yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(analytics.recentEvents.suffix(50).reversed()) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(event.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(event.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !event.properties.isEmpty {
                            Text(propertyLine(event.properties))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func propertyLine(_ properties: [String: String]) -> String {
        properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "  ")
    }

    private func formatLatency(_ latency: TimeInterval?) -> String {
        guard let latency else { return "—" }
        return String(format: "%.0f ms", latency * 1000)
    }
}
