//
//  Formatters.swift
//  CryptoSim
//
//  Centralized display formatting. v1 had free functions scattered in
//  Models.swift and allocated a DateFormatter per call (they're expensive
//  to create); here formatters are cached statics.
//

import Foundation

enum Formatters {
    private static let transactionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        return formatter
    }()

    /// Grouped dollar formatter for values >= $1 ("$10,000.00"). Locale is
    /// pinned because the app quotes everything in USD.
    private static let dollarFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// USD price with precision that adapts to magnitude, so sub-cent
    /// coins (e.g. SHIB) don't render as "$0.00".
    static func currency(_ value: Double) -> String {
        if value == 0 {
            return "$0.00"
        } else if value >= 1 {
            return dollarFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
        } else if value >= 0.01 {
            return String(format: "$%.4f", value)
        } else {
            return String(format: "$%.6f", value)
        }
    }

    /// "$1.17T", "$45.80B", "$12.30M" for market caps and volume.
    static func largeCurrency(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }

    /// "19.50M", "1.20B" for coin supply figures.
    static func supply(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.2fK", value / 1_000)
        } else {
            return String(format: "%.2f", value)
        }
    }

    /// "+2.45%" / "-1.10%"
    static func signedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    /// "+$123.45" / "-$67.89"
    static func signedCurrency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(currency(abs(value)))"
    }

    /// Crypto quantity: up to 6 decimal places with trailing zeros trimmed,
    /// so 0.05 reads "0.05", not "0.050000".
    static func coinAmount(_ value: Double) -> String {
        var text = String(format: "%.6f", value)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    /// Rounds a quantity *down* at 6 decimals. Used when pre-filling trade
    /// amounts from a computed maximum — plain "%.6f" rounds to nearest,
    /// which can round UP past the maximum and make the MAX button produce
    /// an unaffordable amount.
    static func floorToCoinPrecision(_ value: Double) -> Double {
        (value * 1_000_000).rounded(.down) / 1_000_000
    }

    static func transactionDate(_ date: Date) -> String {
        transactionDateFormatter.string(from: date)
    }

    /// Parses user-typed amounts, accepting both "0.5" and "0,5" so a
    /// device set to a comma-decimal locale still works (v1 only accepted
    /// dot-decimal input via `Double(...)`).
    static func parseAmount(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let value = Double(trimmed) { return value }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
}
