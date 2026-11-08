import SwiftUI

enum Theme {
    static let background = Color(red: 0.055, green: 0.067, blue: 0.078)
    static let surface = Color(red: 0.085, green: 0.10, blue: 0.115)
    static let elevated = Color(red: 0.12, green: 0.14, blue: 0.155)
    static let accent = Color(red: 0.43, green: 0.94, blue: 0.77)
    static let secondary = Color(red: 0.57, green: 0.63, blue: 0.66)
    static let border = Color.white.opacity(0.085)
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(configuration.isPressed ? Theme.elevated : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct KeyCap: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.border))
    }
}
