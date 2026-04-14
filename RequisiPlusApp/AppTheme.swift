import SwiftUI

enum AppTheme {
    static let deepBlue = Color(hex: "#0A1F44")
    static let midBlue = Color(hex: "#153B7A")
    static let primaryBlue = Color(hex: "#2C63FF")
    static let textPrimary = Color(hex: "#111827")
    static let textMuted = Color(hex: "#6B7280")
    static let fieldFill = Color(hex: "#F8FAFC")
    static let fieldBorder = Color(hex: "#D9E2F1")
    static let softBlue = Color(red: 0.84, green: 0.92, blue: 1.0)
    static let cardBlue = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let warmAlert = Color(red: 0.98, green: 0.93, blue: 0.80)
    static let warmAlertBorder = Color(red: 0.90, green: 0.76, blue: 0.36)
    static let success = Color(red: 0.21, green: 0.65, blue: 0.44)
    static let whiteOverlay = Color.white.opacity(0.52)

    static let backgroundGradient = LinearGradient(
        colors: [Color.white, Color(red: 0.95, green: 0.97, blue: 1.0), softBlue.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarGradient = LinearGradient(
        colors: [deepBlue.opacity(0.92), primaryBlue.opacity(0.80)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
