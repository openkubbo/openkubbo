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
        let gitHubOAuthService = GitHubOAuthService()
        let gitHubAPIService = GitHubAPIService()
        let gitHubTokenStore = KeychainGitHubTokenStore()

        self.themeStore = themeStore
        self.settingsViewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: gitHubOAuthService,
            gitHubAPIService: gitHubAPIService,
            gitHubTokenStore: gitHubTokenStore
        )
        self.menuBarViewModel = MenuBarViewModel()
    }
}
