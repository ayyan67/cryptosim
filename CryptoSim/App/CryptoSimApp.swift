//
//  CryptoSimApp.swift
//  CryptoSim
//
//  Composition root: every dependency (network client → market data
//  service → stores, analytics, metrics) is constructed here and injected
//  down. Nothing below this file reaches for a singleton.
//
//  v1 called fatalError() if the SwiftData container failed to open —
//  a guaranteed crash-on-launch for affected users. v2 falls back to an
//  in-memory store: the session still works (trades just won't persist),
//  and the failure is logged as a fault for follow-up.
//

import SwiftUI
import SwiftData

@main
struct CryptoSimApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var marketStore: MarketStore
    @StateObject private var portfolioStore: PortfolioStore
    @StateObject private var analytics: LocalAnalyticsTracker
    @StateObject private var metrics: MetricsCollector

    init() {
        // Observability first, so everything else can be instrumented.
        let metricsCollector = MetricsCollector()
        let analyticsTracker = LocalAnalyticsTracker()

        // Persistence, with a graceful degradation path.
        let schema = Schema([
            Holding.self,
            Transaction.self,
            WatchlistItem.self,
            Portfolio.self
        ])
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
        } catch {
            AppLog.persistence.fault("Persistent container failed (\(error.localizedDescription, privacy: .public)) — falling back to in-memory storage")
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
            } catch {
                // Even the in-memory container failed — this indicates a
                // programmer error in the schema, so surfacing it loudly
                // in development is correct.
                fatalError("In-memory ModelContainer failed: \(error)")
            }
        }
        modelContainer = container

        // Networking → domain service → stores.
        let networkClient = URLSessionNetworkClient(metrics: metricsCollector)
        let marketService = CoinGeckoMarketDataService(client: networkClient)

        _marketStore = StateObject(wrappedValue: MarketStore(
            service: marketService,
            analytics: analyticsTracker
        ))
        _portfolioStore = StateObject(wrappedValue: PortfolioStore(
            modelContext: container.mainContext,
            analytics: analyticsTracker
        ))
        _analytics = StateObject(wrappedValue: analyticsTracker)
        _metrics = StateObject(wrappedValue: metricsCollector)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(marketStore)
                .environmentObject(portfolioStore)
                .environmentObject(analytics)
                .environmentObject(metrics)
        }
        .modelContainer(modelContainer)
    }
}
