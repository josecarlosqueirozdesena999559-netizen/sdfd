import SwiftUI

enum AppTheme {
    static let primaryBlue = Color(red: 0.15, green: 0.45, blue: 0.88)
    static let deepBlue = Color(red: 0.08, green: 0.22, blue: 0.42)
    static let midBlue = Color(red: 0.13, green: 0.31, blue: 0.58)
    static let softBlue = Color(red: 0.84, green: 0.92, blue: 1.0)
    static let cardBlue = Color(red: 0.92, green: 0.96, blue: 1.0)
    static let fieldFill = Color(red: 0.97, green: 0.98, blue: 1.0)
    static let fieldBorder = Color(red: 0.84, green: 0.89, blue: 0.95)
    static let textPrimary = Color(red: 0.14, green: 0.18, blue: 0.25)
    static let textMuted = Color(red: 0.44, green: 0.50, blue: 0.58)
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
