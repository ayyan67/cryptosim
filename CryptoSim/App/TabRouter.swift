//
//  TabRouter.swift
//  CryptoSim
//
//  Programmatic tab navigation. Owning the TabView selection in an
//  observable object lets any screen route the user somewhere actionable —
//  e.g. the empty portfolio's "Browse Market" button actually switches to
//  the Market tab instead of being a dead suggestion.
//

import Foundation
import Combine

enum AppTab: Hashable {
    case portfolio
    case market
    case watchlist
    case history
    case metrics
}

@MainActor
final class TabRouter: ObservableObject {
    @Published var selection: AppTab = .portfolio
}
