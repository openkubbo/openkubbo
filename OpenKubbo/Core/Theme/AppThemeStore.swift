import Combine
import SwiftUI

@MainActor
final class AppThemeStore: ObservableObject {
    @Published var selectedTheme: AppTheme

    init(selectedTheme: AppTheme = .automatic) {
        self.selectedTheme = selectedTheme
    }

    func apply(_ theme: AppTheme) {
        selectedTheme = theme
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
}
