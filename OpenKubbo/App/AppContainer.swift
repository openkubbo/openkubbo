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
        let geminiAPIKeyStore = KeychainGeminiAPIKeyStore()
        let codexExecutableResolver = DefaultCodexCLIExecutableResolver()
        let geminiExecutableResolver = DefaultGeminiCLIExecutableResolver()
        let nodeExecutableResolver = DefaultNodeRuntimeExecutableResolver()
        let localRootProvider = SettingsLocalRepositoryRootProvider(settingsRepository: settingsRepository)
        let localResolver = LocalRepositoryResolver()
        let localActionService = RepositoryLocalActionService()
        let codexTaskIdeaGenerator = CodexCLITaskIdeaGenerator(
            settingsRepository: settingsRepository,
            apiKeyStore: codexAPIKeyStore,
            executableResolver: codexExecutableResolver,
            nodeExecutableResolver: nodeExecutableResolver
        )
        let geminiTaskIdeaGenerator = GeminiCLITaskIdeaGenerator(
            settingsRepository: settingsRepository,
            apiKeyStore: geminiAPIKeyStore,
            executableResolver: geminiExecutableResolver,
            nodeExecutableResolver: nodeExecutableResolver
        )
        let taskIdeaGenerator = ProviderBackedTaskIdeaGenerator(
            settingsRepository: settingsRepository,
            openAITaskIdeaGenerator: codexTaskIdeaGenerator,
            googleTaskIdeaGenerator: geminiTaskIdeaGenerator
        )

        self.themeStore = themeStore
        self.taskIdeaGenerator = taskIdeaGenerator
        self.settingsViewModel = SettingsViewModel(
            repository: settingsRepository,
            themeStore: themeStore,
            gitHubOAuthService: gitHubOAuthService,
            gitHubTokenStore: gitHubTokenStore,
            codexAPIKeyStore: codexAPIKeyStore,
            codexExecutableResolver: codexExecutableResolver,
            geminiAPIKeyStore: geminiAPIKeyStore,
            geminiExecutableResolver: geminiExecutableResolver,
            nodeExecutableResolver: nodeExecutableResolver
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
            repository: InMemoryTaskRepository(),
            ideaGenerator: taskIdeaGenerator
        )
    }
}
