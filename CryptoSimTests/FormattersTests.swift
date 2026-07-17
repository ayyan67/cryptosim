//
//  FormattersTests.swift
//  CryptoSimTests
//
//  Display formatting edge cases: magnitude-adaptive precision, grouping,
//  zero, and signed values.
//

import XCTest
@testable import CryptoSim

final class FormattersTests: XCTestCase {
    func testCurrencyGroupsThousands() {
        XCTAssertEqual(Formatters.currency(10_000), "$10,000.00")
        XCTAssertEqual(Formatters.currency(1_234_567.89), "$1,234,567.89")
    }

    func testCurrencyZeroIsPlainTwoDecimals() {
        XCTAssertEqual(Formatters.currency(0), "$0.00")
    }

    func testCurrencyAdaptsPrecisionToMagnitude() {
        XCTAssertEqual(Formatters.currency(60_000.12), "$60,000.12")
        XCTAssertEqual(Formatters.currency(0.5), "$0.5000")
        XCTAssertEqual(Formatters.currency(0.00001723), "$0.000017")
    }

    func testSignedCurrency() {
        XCTAssertEqual(Formatters.signedCurrency(123.45), "+$123.45")
        XCTAssertEqual(Formatters.signedCurrency(-67.89), "-$67.89")
        XCTAssertEqual(Formatters.signedCurrency(0), "+$0.00")
    }

    func testSignedPercent() {
        XCTAssertEqual(Formatters.signedPercent(2.456), "+2.46%")
        XCTAssertEqual(Formatters.signedPercent(-1.1), "-1.10%")
    }

    func testLargeCurrencyUnits() {
        XCTAssertEqual(Formatters.largeCurrency(1_170_000_000_000), "$1.17T")
        XCTAssertEqual(Formatters.largeCurrency(45_800_000_000), "$45.80B")
        XCTAssertEqual(Formatters.largeCurrency(12_300_000), "$12.30M")
        XCTAssertEqual(Formatters.largeCurrency(999), "$999.00")
    }

    func testParseAmountAcceptsDotAndComma() {
        XCTAssertEqual(Formatters.parseAmount("0.5") ?? 0, 0.5, accuracy: 1e-12)
        XCTAssertEqual(Formatters.parseAmount("0,5") ?? 0, 0.5, accuracy: 1e-12)
        XCTAssertEqual(Formatters.parseAmount(" 1.25 ") ?? 0, 1.25, accuracy: 1e-12)
        XCTAssertNil(Formatters.parseAmount(""))
        XCTAssertNil(Formatters.parseAmount("abc"))
    }
}
