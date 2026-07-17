//
//  MarketDataService.swift
//  CryptoSim
//
//  Domain-level API for market data. Views and stores talk to
//  `MarketDataProviding`; the CoinGecko implementation is one concrete
//  provider behind it. This is the seam that makes MarketStore and the
//  view models unit-testable with a mock.
//

import Foundation

protocol MarketDataProviding {
    /// Top coins by market cap, with 7-day sparklines.
    func fetchTopCoins() async throws -> [CoinMarketData]

    /// Price series for one coin over the last `days` days.
    func fetchPriceChart(coinId: String, days: Int) async throws -> [Double]
}

final class CoinGeckoMarketDataService: MarketDataProviding {
    private let client: NetworkClient
    private let decoder = JSONDecoder()

    /// How many coins to load. 30 keeps the free-tier payload (with
    /// sparklines) fast; pagination is the obvious next step.
    private let coinsPerPage = 30

    init(client: NetworkClient) {
        self.client = client
    }

    func fetchTopCoins() async throws -> [CoinMarketData] {
        let endpoint = CoinGeckoAPI.markets(currency: "usd", perPage: coinsPerPage, page: 1)
        guard let url = endpoint.url else { throw APIError.invalidURL }

        let data = try await client.get(url, endpointName: endpoint.endpointName)
        do {
            return try decoder.decode([CoinMarketData].self, from: data)
        } catch {
            AppLog.network.error("Decoding coins/markets failed: \(error.localizedDescription, privacy: .public)")
            throw APIError.decodingError(description: error.localizedDescription)
        }
    }

    func fetchPriceChart(coinId: String, days: Int) async throws -> [Double] {
        let endpoint = CoinGeckoAPI.marketChart(coinId: coinId, currency: "usd", days: days)
        guard let url = endpoint.url else { throw APIError.invalidURL }

        let data = try await client.get(url, endpointName: endpoint.endpointName)
        do {
            return try decoder.decode(PriceChartData.self, from: data).priceValues
        } catch {
            AppLog.network.error("Decoding market_chart failed: \(error.localizedDescription, privacy: .public)")
            throw APIError.decodingError(description: error.localizedDescription)
        }
    }
}
