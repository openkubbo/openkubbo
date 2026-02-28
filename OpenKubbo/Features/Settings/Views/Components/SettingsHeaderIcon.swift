import SwiftUI

struct SettingsHeaderIcon: View {
    let symbol: String
    var isActive = false
    var isDarkTheme = false
    var accentColor = Color(red: 0.39, green: 0.44, blue: 0.99)

    private var symbolColor: Color {
        if isActive {
            return .white.opacity(0.94)
        }
        return isDarkTheme ? .white.opacity(0.66) : .black.opacity(0.62)
    }

    private var fillColor: Color {
        if isActive {
            return accentColor
        }
        return isDarkTheme ? Color(red: 0.20, green: 0.20, blue: 0.21) : .white
    }

    private var strokeColor: Color {
        if isActive {
            return accentColor.opacity(isDarkTheme ? 0.72 : 0.64)
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
