//
//  StatCard.swift
//  CryptoSim
//
//  Small labeled-value card used across detail and performance screens.
//  Replaces three near-identical structs from v1 (StatCard, MarketStatCard,
//  BreakdownCard).
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCard(title: "Market Cap", value: "$1.17T")
        StatCard(title: "24h Change", value: "+2.45%", valueColor: .green)
    }
    .padding()
    .background(Color.appBackground)
}
