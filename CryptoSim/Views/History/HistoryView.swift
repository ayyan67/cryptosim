//
//  HistoryView.swift
//  CryptoSim
//
//  History tab: every buy/sell, filterable by type and searchable by coin.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var analytics: LocalAnalyticsTracker
    @EnvironmentObject var router: TabRouter

    @State private var filterType: FilterType = .all
    @State private var searchText = ""

    enum FilterType: String, CaseIterable {
        case all = "All"
        case buy = "Buy"
        case sell = "Sell"
    }

    private var filteredTransactions: [Transaction] {
        var transactions = portfolioStore.transactions

        switch filterType {
        case .all:
            break
        case .buy:
            transactions = transactions.filter { $0.type == .buy }
        case .sell:
            transactions = transactions.filter { $0.type == .sell }
        }

        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let query = trimmed.lowercased()
            transactions = transactions.filter {
                $0.coinName.lowercased().contains(query) ||
                $0.symbol.lowercased().contains(query)
            }
        }

        return transactions
    }

    var body: some View {
        NavigationStack {
            Group {
                if portfolioStore.transactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search transactions")
            .background(Color.appBackground)
            .onAppear {
                analytics.track(.screenViewed(name: "history"))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No transactions yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Your buy and sell history will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Browse Market") {
                router.selection = .market
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transactionList: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        FilterPill(
                            title: type.rawValue,
                            isSelected: filterType == type
                        ) {
                            filterType = type
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            if filteredTransactions.isEmpty {
                // Transactions exist but the filter/search matches none —
                // say so instead of showing a silently blank list.
                ContentUnavailableView(
                    "No matching transactions",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different filter or search term")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredTransactions, id: \.id) { transaction in
                    HistoryRow(transaction: transaction)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.appCard)
                .cornerRadius(20)
        }
    }
}

struct HistoryRow: View {
    let transaction: Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(transaction.type.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(transaction.type == .buy ? Color.green : Color.red)
                    .cornerRadius(12)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(.headline)

                    Text(transaction.formattedTotal)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.coinName)
                    .font(.headline)

                Text(transaction.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
