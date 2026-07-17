//
//  ChartView.swift
//  CryptoSim
//
//  Hand-rolled line chart in pure SwiftUI: a stroked Path over a gradient
//  fill, normalized to the data's min/max. Deliberately not Swift Charts —
//  building it from Path was the point (and it renders 200+ points fine).
//

import SwiftUI

struct ChartView: View {
    let data: [Double]
    let isPositive: Bool

    var body: some View {
        GeometryReader { geometry in
            if data.count > 1 {
                let minValue = data.min() ?? 0
                let maxValue = data.max() ?? 1
                let range = maxValue - minValue
                // Guard against a flat series (range 0 would divide by zero).
                let adjustedRange = range > 0 ? range : 1

                // Price line
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let step = width / CGFloat(data.count - 1)

                    for (index, value) in data.enumerated() {
                        let x = step * CGFloat(index)
                        let y = height - (CGFloat((value - minValue) / adjustedRange) * height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: isPositive ? [.green.opacity(0.8), .green] : [.red.opacity(0.8), .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // Area fill under the line
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let step = width / CGFloat(data.count - 1)

                    path.move(to: CGPoint(x: 0, y: height))

                    for (index, value) in data.enumerated() {
                        let x = step * CGFloat(index)
                        let y = height - (CGFloat((value - minValue) / adjustedRange) * height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: geometry.size.width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            isPositive ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                            isPositive ? Color.green.opacity(0.05) : Color.red.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                Text("No chart data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appCard)
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        ChartView(data: [59000, 59500, 60000, 59800, 60200, 60500, 61000], isPositive: true)
            .frame(height: 200)
        ChartView(data: [61000, 60500, 60200, 59800, 60000, 59500, 59000], isPositive: false)
            .frame(height: 200)
    }
    .padding()
    .background(Color.appBackground)
}
