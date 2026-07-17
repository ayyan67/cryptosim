//
//  RootTabView.swift
//  CryptoSim
//
//  Tab container. The 30-second auto-refresh pipeline lives inside
//  MarketStore (owned state, not view state — a view-held Timer.publish
//  gets recreated on every re-render); this view just starts it and
//  forwards scene-phase changes. Tab selection is owned by TabRouter so
//  screens can navigate programmatically. In DEBUG builds a fifth tab
//  exposes the metrics dashboard.
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var marketStore: MarketStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = TabRouter()

    var body: some View {
        TabView(selection: $router.selection) {
            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }
                .tag(AppTab.portfolio)

            MarketView()
                .tabItem {
                    Label("Market", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.market)

            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "star.fill")
                }
                .tag(AppTab.watchlist)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(AppTab.history)

            #if DEBUG
            MetricsDashboardView()
                .tabItem {
                    Label("Metrics", systemImage: "gauge.with.dots.needle.67percent")
                }
                .tag(AppTab.metrics)
            #endif
        }
        .environmentObject(router)
        .accentColor(.blue)
        .preferredColorScheme(.dark)
        .task {
            marketStore.startAutoRefresh()
            await marketStore.refresh(source: .appLaunch)
        }
        .onChange(of: scenePhase) { _, newPhase in
            marketStore.setSceneActive(newPhase == .active)
        }
    }
}
