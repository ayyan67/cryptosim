//
//  AppLog.swift
//  CryptoSim
//
//  Structured logging via os.Logger, split into subsystem categories so
//  logs can be filtered in Console.app / Xcode debug console per area.
//

import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "AyyanQamer.CryptoSim"

    /// Network requests, responses, retries, rate limits.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Buy/sell execution, balance changes, validation failures.
    static let trading = Logger(subsystem: subsystem, category: "trading")

    /// SwiftData container setup, fetches, saves.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Screen lifecycle and user-facing state transitions.
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Analytics event stream (mirrors what a real backend would receive).
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
}
