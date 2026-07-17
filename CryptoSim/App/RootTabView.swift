//
//  RootTabView.swift
//  CryptoSim
//
//  Tab container + the app's refresh cycle. The 30-second auto-refresh
//  only fires while the scene is active, and returning to the foreground
//  triggers an immediate refresh (v1's timer refreshed unconditionally).
//  In DEBUG builds a fifth tab exposes the metrics dashboard.
//

import SwiftUI
import Combine

struct RootTabView: View {
    @EnvironmentObject var marketStore: MarketStore
    @Environment(\.scenePhase) private var scenePhase

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            PortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }

            MarketView()
                .tabItem {
                    Label("Market", systemImage: "chart.line.uptrend.xyaxis")
                }

            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "star.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }

            #if DEBUG
            MetricsDashboardView()
                .tabItem {
                    Label("Metrics", systemImage: "gauge.with.dots.needle.67percent")
                }
            #endif
        }
        .accentColor(.blue)
        .preferredColorScheme(.dark)
        .task {
            await marketStore.refresh(source: .appLaunch)
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            Task {
                await marketStore.refresh(force: true, source: .autoTimer)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await marketStore.refresh(source: .foreground)
                }
            }
        }
    }
}
