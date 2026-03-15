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

    private let taskIdeaGenerator: TaskIdeaGenerating

    init() {
        self.appUpdateController = AppUpdateController()

        let themeStore = AppThemeStore()
        let settingsRepository = UserDefaultsSettingsRepository()
        let gitHubOAuthService = GitHubOAuthService()
        let gitHubAPIService = GitHubAPIService()
        let gitHubTokenStore = KeychainGitHubTokenStore()
        let codexAPIKeyStore = KeychainCodexAPIKeyStore()
        let codexExecutableResolver = DefaultCodexCLIExecutableResolver()
        let localRootProvider = SettingsLocalRepositoryRootProvider(settingsRepository: settingsRepository)
        let localResolver = LocalRepositoryResolver()
        let localActionService = RepositoryLocalActionService()
        let taskIdeaGenerator = CodexCLITaskIdeaGenerator(
            settingsRepository: settingsRepository,
            apiKeyStore: codexAPIKeyStore,
            executableResolver: codexExecutableResolver
        )

        self.themeStore = themeStore
        self.taskIdeaGenerator = taskIdeaGenerator
        self.settingsViewModel = SettingsViewModel(
            repository: settingsRepository,
            themeStore: themeStore,
            gitHubOAuthService: gitHubOAuthService,
            gitHubTokenStore: gitHubTokenStore,
            codexAPIKeyStore: codexAPIKeyStore,
            codexExecutableResolver: codexExecutableResolver
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

    func makeTaskViewModel() -> TaskViewModel {
        TaskViewModel(
            repository: UserDefaultsTaskRepository(),
            ideaGenerator: taskIdeaGenerator
        )
    }
}
