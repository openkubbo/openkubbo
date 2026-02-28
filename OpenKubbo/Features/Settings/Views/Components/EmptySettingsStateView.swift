import SwiftUI

struct EmptySettingsStateView: View {
    var isDarkTheme = false

    private var textColor: Color {
        isDarkTheme ? .white.opacity(0.58) : .black.opacity(0.50)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.20, blue: 0.21) : .white
    }

    private var strokeColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
            Text("Nenhum ajuste encontrado")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        )
    }
}
