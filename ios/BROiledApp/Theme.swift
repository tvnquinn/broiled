import SwiftUI

/// "Char & Ember" palette - matches wireframe_phase0.html exactly. Semantic tints,
/// never a filled celebratory green (success is bronze/backhanded, not a checkmark).
enum Theme {
    static let bg = Color(hex: 0x0C0C0E)
    static let panel = Color(hex: 0x1A1A1F)
    static let line = Color(hex: 0x2E2E33)
    static let lineStrong = Color(hex: 0x3D3D42)
    static let ink = Color(hex: 0xF2F0ED)
    static let inkMuted = Color(hex: 0xF2F0ED, alpha: 0.65)
    static let chrome = Color(hex: 0x0A0A0C)

    static let accent = Color(hex: 0xFF6B2B)       // ember - countdown, primary CTAs
    static let flame = Color(hex: 0xFF3B30)        // miss reckoning, destructive
    static let success = Color(hex: 0xC9A227)      // bronze - backhanded success, never green
    static let ash = Color(hex: 0x48484A)          // silence / muted states
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
