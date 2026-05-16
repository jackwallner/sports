import SwiftUI

enum SidelineTheme {
    static let brandPrimary = Color(red: 0.122, green: 0.361, blue: 0.271)
    static let brandAccent = Color(red: 0.878, green: 0.635, blue: 0.102)
    static let amberText = Color(red: 0.322, green: 0.212, blue: 0.000)
    static let tagNiceGuy = Color(red: 0.180, green: 0.490, blue: 0.310)
    static let tagJerk = Color(red: 0.706, green: 0.271, blue: 0.184)
    static let cardCornerRadius: CGFloat = 16
}

extension Color {
    static var sidelineCard: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.secondary.opacity(0.12)
        #endif
    }

    static var sidelineBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.clear
        #endif
    }
}
