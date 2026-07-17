//
//  CoinIconView.swift
//  CryptoSim
//
//  Circular coin logo with a lettered placeholder while loading.
//  v1 duplicated this AsyncImage + placeholder block in six views;
//  extracting it is the DRY fix and gives one place to add caching later.
//

import SwiftUI

struct CoinIconView: View {
    let imageURL: String
    let symbol: String
    var size: CGFloat = 40
    var placeholderTint: Color = .blue

    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            Circle()
                .fill(placeholderTint.opacity(0.2))
                .overlay(
                    Text(String(symbol.prefix(1)).uppercased())
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundColor(placeholderTint)
                )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 20) {
        CoinIconView(imageURL: "", symbol: "btc", size: 40)
        CoinIconView(imageURL: "", symbol: "eth", size: 60, placeholderTint: .purple)
        CoinIconView(imageURL: "https://assets.coingecko.com/coins/images/1/large/bitcoin.png", symbol: "btc", size: 80)
    }
    .padding()
    .background(Color.appBackground)
}
