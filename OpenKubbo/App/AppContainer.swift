import Combine
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    let themeStore: AppThemeStore
    let settingsViewModel: SettingsViewModel
    let menuBarViewModel: MenuBarViewModel

    init() {
        let themeStore = AppThemeStore()
        let repository = UserDefaultsSettingsRepository()

        self.themeStore = themeStore
        self.settingsViewModel = SettingsViewModel(repository: repository, themeStore: themeStore)
        self.menuBarViewModel = MenuBarViewModel()
    }
}
