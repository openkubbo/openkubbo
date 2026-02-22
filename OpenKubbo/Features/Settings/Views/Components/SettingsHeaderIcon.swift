import SwiftUI

struct SettingsHeaderIcon: View {
    let symbol: String
    var isActive = false
    var isDarkTheme = false

    private var symbolColor: Color {
        isDarkTheme ? .white.opacity(isActive ? 0.84 : 0.66) : .black.opacity(isActive ? 0.82 : 0.62)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.21, blue: 0.25) : .white
    }

    private var strokeColor: Color {
        if isActive {
            return Color(red: 0.42, green: 0.41, blue: 0.80).opacity(0.45)
        }
        return isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.10)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: 42, height: 42)
            .background(
                Circle()
                    .fill(fillColor)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
    }
}
