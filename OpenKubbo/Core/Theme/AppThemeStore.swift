import Combine
import SwiftUI

@MainActor
final class AppThemeStore: ObservableObject {
    @Published var selectedTheme: AppTheme
    @Published private(set) var selectedAccentColorIndex: Int

    var accentPalette: [Color] {
        Self.defaultAccentPalette
    }

    var accentColor: Color {
        guard !Self.defaultAccentPalette.isEmpty else {
            return Color(red: 0.39, green: 0.44, blue: 0.99)
        }
        return Self.defaultAccentPalette[selectedAccentColorIndex]
    }

    init(
        selectedTheme: AppTheme = .automatic,
        selectedAccentColorIndex: Int = 0
    ) {
        self.selectedTheme = selectedTheme
        self.selectedAccentColorIndex = Self.clampedAccentColorIndex(selectedAccentColorIndex)
    }

    func apply(_ theme: AppTheme) {
        selectedTheme = theme
    }

    func applyAccentColorIndex(_ index: Int) {
        selectedAccentColorIndex = Self.clampedAccentColorIndex(index)
    }

    func resolvedColorScheme(systemColorScheme: ColorScheme) -> ColorScheme {
        switch selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .automatic:
            return systemColorScheme
        }
    }

    private static let defaultAccentPalette: [Color] = [
        Color(red: 0.39, green: 0.44, blue: 0.99),
        Color(red: 0.30, green: 0.53, blue: 0.98),
        Color(red: 0.55, green: 0.35, blue: 0.88),
        Color(red: 0.83, green: 0.30, blue: 0.62),
        Color(red: 0.88, green: 0.29, blue: 0.33),
        Color(red: 0.90, green: 0.47, blue: 0.19),
        Color(red: 0.23, green: 0.73, blue: 0.41),
        Color(red: 0.95, green: 0.78, blue: 0.18),
        Color(red: 0.58, green: 0.38, blue: 0.22)
    ]

    private static func clampedAccentColorIndex(_ index: Int) -> Int {
        guard !defaultAccentPalette.isEmpty else { return 0 }
        return min(max(index, 0), defaultAccentPalette.count - 1)
    }
}
