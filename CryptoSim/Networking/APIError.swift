//
//  APIError.swift
//  CryptoSim
//
//  Typed errors for the networking layer. v1 surfaced raw strings; typed
//  errors let callers branch on the failure (e.g. show a "rate limited,
//  showing cached data" banner vs. a generic failure) and make tests exact.
//

import Foundation

enum APIError: Error, Equatable {
    case invalidURL
    case rateLimited                 // HTTP 429 — CoinGecko free tier
    case serverError(statusCode: Int)
    case transportError(description: String)
    case decodingError(description: String)

    /// Transient failures are worth an automatic retry; the rest are not.
    var isTransient: Bool {
        switch self {
        case .transportError: return true
        case .serverError(let code): return (500...599).contains(code)
        case .invalidURL, .rateLimited, .decodingError: return false
        }
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .rateLimited:
            return "Rate limit reached. Showing cached data."
        case .serverError(let statusCode):
            return "Server error (\(statusCode)). Please try again."
        case .transportError:
            return "Network unavailable. Check your connection."
        case .decodingError:
            return "Unexpected response from server."
        }
    }
}
