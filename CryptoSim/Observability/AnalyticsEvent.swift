//
//  AnalyticsEvent.swift
//  CryptoSim
//
//  Typed analytics events. Using an enum (rather than free-form strings at
//  call sites) means every event the app can emit is defined in one place,
//  is impossible to typo, and is easy to review in a PR.
//

import Foundation

enum AnalyticsEvent {
    case screenViewed(name: String)
    case marketRefreshed(source: RefreshSource, coinCount: Int)
    case marketRefreshFailed(reason: String)
    case searchPerformed(resultCount: Int)
    case sortChanged(option: String, ascending: Bool)
    case coinDetailOpened(coinId: String)
    case chartRangeChanged(coinId: String, days: Int)
    case tradeSheetOpened(coinId: String, side: String)
    case tradeExecuted(coinId: String, side: String, amount: Double, totalValue: Double)
    case tradeFailed(coinId: String, side: String, reason: String)
    case watchlistAdded(coinId: String)
    case watchlistRemoved(coinId: String)
    case portfolioReset

    enum RefreshSource: String {
        case appLaunch = "app_launch"
        case autoTimer = "auto_timer"
        case pullToRefresh = "pull_to_refresh"
        case retryButton = "retry_button"
        case foreground = "foreground"
    }

    /// Stable snake_case event name — what a warehouse table would key on.
    var name: String {
        switch self {
        case .screenViewed: return "screen_viewed"
        case .marketRefreshed: return "market_refreshed"
        case .marketRefreshFailed: return "market_refresh_failed"
        case .searchPerformed: return "search_performed"
        case .sortChanged: return "sort_changed"
        case .coinDetailOpened: return "coin_detail_opened"
        case .chartRangeChanged: return "chart_range_changed"
        case .tradeSheetOpened: return "trade_sheet_opened"
        case .tradeExecuted: return "trade_executed"
        case .tradeFailed: return "trade_failed"
        case .watchlistAdded: return "watchlist_added"
        case .watchlistRemoved: return "watchlist_removed"
        case .portfolioReset: return "portfolio_reset"
        }
    }

    var properties: [String: String] {
        switch self {
        case .screenViewed(let name):
            return ["screen": name]
        case .marketRefreshed(let source, let coinCount):
            return ["source": source.rawValue, "coin_count": String(coinCount)]
        case .marketRefreshFailed(let reason):
            return ["reason": reason]
        case .searchPerformed(let resultCount):
            return ["result_count": String(resultCount)]
        case .sortChanged(let option, let ascending):
            return ["option": option, "ascending": String(ascending)]
        case .coinDetailOpened(let coinId):
            return ["coin_id": coinId]
        case .chartRangeChanged(let coinId, let days):
            return ["coin_id": coinId, "days": String(days)]
        case .tradeSheetOpened(let coinId, let side):
            return ["coin_id": coinId, "side": side]
        case .tradeExecuted(let coinId, let side, let amount, let totalValue):
            return [
                "coin_id": coinId,
                "side": side,
                "amount": String(amount),
                "total_value": String(format: "%.2f", totalValue)
            ]
        case .tradeFailed(let coinId, let side, let reason):
            return ["coin_id": coinId, "side": side, "reason": reason]
        case .watchlistAdded(let coinId):
            return ["coin_id": coinId]
        case .watchlistRemoved(let coinId):
            return ["coin_id": coinId]
        case .portfolioReset:
            return [:]
        }
    }
}
