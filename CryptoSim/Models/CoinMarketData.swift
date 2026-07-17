//
//  CoinMarketData.swift
//  CryptoSim
//
//  Decodable models for the CoinGecko API. Uses `convertFromSnakeCase`-style
//  explicit CodingKeys so the mapping from API fields is visible and
//  greppable. Most numeric fields are optional because the free API omits
//  them for some assets.
//

import Foundation

struct CoinMarketData: Codable, Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let marketCap: Double?
    let marketCapRank: Int?
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let priceChange24h: Double?
    let priceChangePercentage24h: Double?
    let circulatingSupply: Double?
    let totalSupply: Double?
    let maxSupply: Double?
    let sparklineIn7d: SparklineData?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case priceChange24h = "price_change_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
        case maxSupply = "max_supply"
        case sparklineIn7d = "sparkline_in_7d"
    }

    var priceChangeIsPositive: Bool {
        (priceChangePercentage24h ?? 0) >= 0
    }

    // MARK: - Display formatting

    var formattedPrice: String {
        Formatters.currency(currentPrice)
    }

    var formattedChange: String {
        Formatters.signedPercent(priceChangePercentage24h ?? 0)
    }

    var formattedMarketCap: String {
        Formatters.largeCurrency(marketCap ?? 0)
    }

    var formattedVolume: String {
        Formatters.largeCurrency(totalVolume ?? 0)
    }

    var formattedCirculatingSupply: String {
        Formatters.supply(circulatingSupply ?? 0) + " " + symbol.uppercased()
    }

    var formattedMaxSupply: String {
        if let max = maxSupply {
            return Formatters.supply(max) + " " + symbol.uppercased()
        }
        return "∞"
    }
}

struct SparklineData: Codable, Equatable {
    let price: [Double]
}

struct PriceChartData: Codable {
    /// CoinGecko returns `[[timestampMillis, price], ...]`.
    let prices: [[Double]]

    /// Just the price series, dropping malformed entries instead of crashing
    /// on `$0[1]` if the API ever returns a short inner array.
    var priceValues: [Double] {
        prices.compactMap { $0.count >= 2 ? $0[1] : nil }
    }
}
