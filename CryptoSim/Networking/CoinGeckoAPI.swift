//
//  CoinGeckoAPI.swift
//  CryptoSim
//
//  Endpoint definitions for the CoinGecko v3 REST API. URLs are built with
//  URLComponents (not string interpolation) so query encoding is always
//  correct, and each endpoint carries a stable logical name for metrics.
//

import Foundation

enum CoinGeckoAPI {
    static let host = "api.coingecko.com"
    static let basePath = "/api/v3"

    case markets(currency: String, perPage: Int, page: Int)
    case marketChart(coinId: String, currency: String, days: Int)

    /// Logical name used in logs and the metrics dashboard. Deliberately
    /// excludes parameters so all chart requests aggregate together.
    var endpointName: String {
        switch self {
        case .markets: return "coins/markets"
        case .marketChart: return "coins/market_chart"
        }
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host

        switch self {
        case .markets(let currency, let perPage, let page):
            components.path = "\(Self.basePath)/coins/markets"
            components.queryItems = [
                URLQueryItem(name: "vs_currency", value: currency),
                URLQueryItem(name: "order", value: "market_cap_desc"),
                URLQueryItem(name: "per_page", value: String(perPage)),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "sparkline", value: "true"),
                URLQueryItem(name: "price_change_percentage", value: "24h")
            ]
        case .marketChart(let coinId, let currency, let days):
            components.path = "\(Self.basePath)/coins/\(coinId)/market_chart"
            components.queryItems = [
                URLQueryItem(name: "vs_currency", value: currency),
                URLQueryItem(name: "days", value: String(days))
            ]
        }
        return components.url
    }
}
