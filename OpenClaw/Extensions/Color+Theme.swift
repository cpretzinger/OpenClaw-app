//
//  Color+Theme.swift
//  OpenClaw
//
//  App color theme definitions - Anthropic-inspired design
//

import SwiftUI

extension Color {
    // MARK: - Anthropic Brand Colors
    static let anthropicCoral = Color(red: 0.85, green: 0.45, blue: 0.40)      // Warm coral/terracotta
    static let anthropicOrange = Color(red: 0.90, green: 0.55, blue: 0.35)     // Soft orange accent
    static let anthropicCream = Color(red: 0.98, green: 0.96, blue: 0.93)      // Warm cream/off-white
    static let anthropicTan = Color(red: 0.92, green: 0.88, blue: 0.82)        // Warm tan
    
    // MARK: - Primary Accent (keeping for compatibility)
    static let orbBlue = anthropicCoral        // Remapped to coral
    static let orbCyan = anthropicOrange       // Remapped to orange
    static let orbPurple = Color(red: 0.75, green: 0.40, blue: 0.45)  // Deeper coral
    
    // MARK: - Background Colors (Dark mode - warm dark tones)
    static let backgroundDark = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let backgroundGradientStart = Color(red: 0.12, green: 0.11, blue: 0.10)
    static let backgroundGradientEnd = Color(red: 0.06, green: 0.05, blue: 0.05)
    
    // MARK: - Surface Colors
    static let surfacePrimary = Color(red: 0.14, green: 0.13, blue: 0.12)
    static let surfaceSecondary = Color(red: 0.18, green: 0.16, blue: 0.15)
    static let surfaceElevated = Color(red: 0.22, green: 0.20, blue: 0.18)
    
    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let textSecondary = Color(red: 0.70, green: 0.66, blue: 0.62)
    static let textTertiary = Color(red: 0.50, green: 0.47, blue: 0.44)
    
    // MARK: - Message Bubble Colors
    static let messageBubbleUser = anthropicCoral
    static let messageBubbleAgent = surfaceSecondary
    
    // MARK: - Status Colors (warmer tones)
    static let statusConnected = Color(red: 0.45, green: 0.75, blue: 0.55)     // Sage green
    static let statusDisconnected = Color(red: 0.85, green: 0.40, blue: 0.40)  // Soft red
    static let statusConnecting = anthropicOrange
    
    // MARK: - Settings Card Colors
    static let cardBackground = surfacePrimary
    static let cardBorder = Color(white: 0.25)
    static let inputBackground = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let accentGlow = anthropicCoral.opacity(0.3)
    
    // MARK: - Gradients
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [.backgroundGradientStart, .backgroundGradientEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var orbGradient: RadialGradient {
        RadialGradient(
            colors: [.anthropicOrange, .anthropicCoral, .anthropicCoral.opacity(0.3)],
            center: .center,
            startRadius: 5,
            endRadius: 50
        )
    }
    
    static var coralGradient: LinearGradient {
        LinearGradient(
            colors: [.anthropicOrange, .anthropicCoral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
