//
//  Theme.swift
//  CryptoSim
//
//  App color palette (originally matched the course HTML/CSS mockups).
//  Centralized so a redesign touches one file.
//

import SwiftUI

extension Color {
    static let appBackground = Color(red: 0.118, green: 0.118, blue: 0.118)   // #1E1E1E
    static let appCard = Color(red: 0.173, green: 0.173, blue: 0.173)         // #2C2C2C
    static let appTextSecondary = Color(red: 0.69, green: 0.69, blue: 0.69)   // #B0B0B0
    static let appSuccess = Color(red: 0, green: 0.784, blue: 0.325)          // #00C853
    static let appError = Color(red: 1, green: 0.231, blue: 0.188)            // #FF3B30
    static let appInfo = Color(red: 0, green: 0.478, blue: 1)                 // #007AFF

    // Balance-card gradient
    static let gradientStart = Color(red: 0.4, green: 0.494, blue: 0.918)     // #667eea
    static let gradientEnd = Color(red: 0.463, green: 0.294, blue: 0.635)     // #764ba2
}
