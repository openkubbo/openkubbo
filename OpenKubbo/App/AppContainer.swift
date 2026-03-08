import Combine
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    let appUpdateController: AppUpdateController
    let themeStore: AppThemeStore
    let settingsViewModel: SettingsViewModel
    let menuBarViewModel: MenuBarViewModel
    let repositoryViewModel: RepositoryViewModel

    init() {
        self.appUpdateController = AppUpdateController()

        let themeStore = AppThemeStore()
        let repository = UserDefaultsSettingsRepository()
        let gitHubOAuthService = GitHubOAuthService()
        let gitHubAPIService = GitHubAPIService()
        let gitHubTokenStore = KeychainGitHubTokenStore()
        let localRootProvider = SettingsLocalRepositoryRootProvider(settingsRepository: repository)
        let localResolver = LocalRepositoryResolver()
        let localActionService = RepositoryLocalActionService()

        self.themeStore = themeStore
        self.settingsViewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: gitHubOAuthService,
            gitHubTokenStore: gitHubTokenStore
        )
        self.menuBarViewModel = MenuBarViewModel()
        self.repositoryViewModel = RepositoryViewModel(
            dataProvider: GitHubRepositoryDataProvider(
                gitHubAPIService: gitHubAPIService,
                gitHubTokenStore: gitHubTokenStore
            ),
            localRootProvider: localRootProvider,
            localResolver: localResolver,
            localActionService: localActionService,
            gitHubTokenStore: gitHubTokenStore
        )
    }
}
