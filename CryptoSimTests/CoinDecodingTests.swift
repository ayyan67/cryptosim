//
//  CoinDecodingTests.swift
//  CryptoSimTests
//
//  Decoding against a real CoinGecko response fixture. Catches API-contract
//  drift (renamed fields, unexpected nulls) at test time instead of as a
//  blank screen in the app.
//

import XCTest
@testable import CryptoSim

final class CoinDecodingTests: XCTestCase {
    private func loadFixture() throws -> Data {
        let bundle = Bundle(for: CoinDecodingTests.self)
        guard let url = bundle.url(forResource: "coins_markets_fixture", withExtension: "json") else {
            throw XCTSkip("Fixture missing from test bundle")
        }
        return try Data(contentsOf: url)
    }

    func testDecodesRealMarketsPayload() throws {
        let data = try loadFixture()

        let coins = try JSONDecoder().decode([CoinMarketData].self, from: data)

        XCTAssertEqual(coins.count, 2)

        let bitcoin = coins[0]
        XCTAssertEqual(bitcoin.id, "bitcoin")
        XCTAssertEqual(bitcoin.currentPrice, 60000.12, accuracy: 0.001)
        XCTAssertEqual(bitcoin.marketCapRank, 1)
        XCTAssertEqual(bitcoin.sparklineIn7d?.price.count, 7)
    }

    func testDecodesCoinWithNullOptionalFields() throws {
        let data = try loadFixture()
        let coins = try JSONDecoder().decode([CoinMarketData].self, from: data)

        // Shiba Inu has max_supply: null and sparkline_in_7d: null.
        let shib = coins[1]
        XCTAssertNil(shib.maxSupply)
        XCTAssertNil(shib.sparklineIn7d)
        XCTAssertEqual(shib.formattedMaxSupply, "∞")
    }

    func testSubCentPriceFormatsWithEnoughPrecision() throws {
        let data = try loadFixture()
        let coins = try JSONDecoder().decode([CoinMarketData].self, from: data)

        // $0.00001723 must not render as "$0.00".
        XCTAssertEqual(coins[1].formattedPrice, "$0.000017")
    }

    func testChartDataDropsMalformedEntries() throws {
        let json = #"{"prices": [[1700000000000, 59000.5], [1700000060000], [1700000120000, 59100.25]]}"#
        let chart = try JSONDecoder().decode(PriceChartData.self, from: Data(json.utf8))

        // The malformed single-element entry is dropped, not crashed on.
        XCTAssertEqual(chart.priceValues, [59000.5, 59100.25])
    }
}
