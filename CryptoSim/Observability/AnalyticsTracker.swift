//
//  AnalyticsTracker.swift
//  CryptoSim
//
//  Analytics is defined as a protocol so views/stores depend on an
//  abstraction: tests inject a spy, previews inject a no-op, and the real
//  app injects LocalAnalyticsTracker. Swapping in a production backend
//  (Amplitude, Statsig, an in-house pipeline) would touch exactly one file.
//

import Foundation
import Combine

protocol AnalyticsTracking: AnyObject {
    func track(_ event: AnalyticsEvent)
}

/// A single recorded event with its timestamp, kept for the in-app
/// metrics dashboard.
struct TrackedEvent: Identifiable {
    let id = UUID()
    let name: String
    let properties: [String: String]
    let timestamp: Date
}

/// Local analytics backend: logs each event, keeps a bounded in-memory
/// ring buffer for the debug dashboard, and persists lifetime event counts
/// to UserDefaults so counts survive relaunches.
@MainActor
final class LocalAnalyticsTracker: ObservableObject, AnalyticsTracking {
    @Published private(set) var recentEvents: [TrackedEvent] = []
    @Published private(set) var lifetimeCounts: [String: Int] = [:]

    private let maxBufferedEvents = 200
    private let defaultsKey = "analytics.lifetimeCounts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lifetimeCounts = (defaults.dictionary(forKey: defaultsKey) as? [String: Int]) ?? [:]
    }

    nonisolated func track(_ event: AnalyticsEvent) {
        let name = event.name
        let properties = event.properties

        let propsDescription = properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        AppLog.analytics.info("\(name, privacy: .public) \(propsDescription, privacy: .public)")

        Task { @MainActor in
            self.record(name: name, properties: properties)
        }
    }

    private func record(name: String, properties: [String: String]) {
        recentEvents.append(TrackedEvent(name: name, properties: properties, timestamp: Date()))
        if recentEvents.count > maxBufferedEvents {
            recentEvents.removeFirst(recentEvents.count - maxBufferedEvents)
        }
        lifetimeCounts[name, default: 0] += 1
        defaults.set(lifetimeCounts, forKey: defaultsKey)
    }

    func resetLifetimeCounts() {
        lifetimeCounts = [:]
        defaults.removeObject(forKey: defaultsKey)
    }
}

/// No-op tracker for SwiftUI previews and tests that don't assert on analytics.
final class NoOpAnalyticsTracker: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
}
