import SwiftUI

struct ShortcutKeysView: View {
    let keys: [String]
    var isDarkTheme = false

    private var textColor: Color {
        isDarkTheme ? .white.opacity(0.84) : .black.opacity(0.78)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.20, blue: 0.21) : .white
    }

    private var strokeColor: Color {
        isDarkTheme ? .white.opacity(0.12) : .black.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                    .frame(minWidth: 26)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(strokeColor, lineWidth: 1)
                            )
                    )
            }
        }
    }
}
