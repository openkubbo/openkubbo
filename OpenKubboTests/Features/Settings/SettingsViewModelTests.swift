import Testing
@testable import OpenKubbo

@MainActor
struct SettingsViewModelTests {
    @Test
    func init_loadsPersistedValues_andAppliesThemeStore() {
        let storedSnapshot = SettingsSnapshot(
            selectedTheme: .dark,
            launchAtLogin: true,
            reopenPreviousWindows: false,
            playCompletionSound: false,
            hapticsEnabled: false,
            appLanguage: "English (US)",
            selectedAccentColorIndex: 2,
            selectedModel: "GPT-4.1",
            temperature: 0.4,
            terminalSuggestionsEnabled: false,
            automaticErrorAnalysis: true,
            syncProfilesEnabled: false
        )

        let repository = InMemorySettingsRepository(snapshot: storedSnapshot)
        let themeStore = AppThemeStore()
        let tokenStore = InMemoryGitHubTokenStore()

        let viewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: StubGitHubOAuthService(),
            gitHubTokenStore: tokenStore
        )

        #expect(viewModel.launchAtLogin)
        #expect(!viewModel.reopenPreviousWindows)
        #expect(viewModel.selectedModel == "GPT-4.1")
        #expect(viewModel.selectedThemeMode == .dark)
        #expect(themeStore.selectedTheme == .dark)
    }

    @Test
    func mutatingState_persistsUpdatedSnapshot() {
        let repository = InMemorySettingsRepository(snapshot: .defaultValue)
        let themeStore = AppThemeStore()
        let tokenStore = InMemoryGitHubTokenStore()

        let viewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: StubGitHubOAuthService(),
            gitHubTokenStore: tokenStore
        )
        viewModel.selectedThemeMode = .light
        viewModel.launchAtLogin = true

        let lastSaved = repository.savedSnapshots.last

        #expect(lastSaved?.selectedTheme == .light)
        #expect(lastSaved?.launchAtLogin == true)
        #expect(themeStore.selectedTheme == .light)
    }

    @Test
    func visibleTabs_filtersUsingSearch() {
        let repository = InMemorySettingsRepository(snapshot: .defaultValue)
        let themeStore = AppThemeStore()
        let tokenStore = InMemoryGitHubTokenStore()

        let viewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: StubGitHubOAuthService(),
            gitHubTokenStore: tokenStore
        )
        viewModel.searchText = "Codex"

        #expect(viewModel.visibleTabs == [.codexCLI])
        #expect(viewModel.activeTab == .codexCLI)
    }

    @Test
    func loginWithGitHub_setsError_whenClientIDIsMissing() async {
        let repository = InMemorySettingsRepository(snapshot: .defaultValue)
        let themeStore = AppThemeStore()
        let tokenStore = InMemoryGitHubTokenStore()

        let viewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: StubGitHubOAuthService(),
            gitHubTokenStore: tokenStore
        )

        await viewModel.loginWithGitHub()

        #expect(viewModel.githubErrorMessage == "Enter your GitHub OAuth App Client ID.")
        #expect(!viewModel.isGitHubConnected)
    }

    @Test
    func loginWithGitHub_storesToken_andSetsConnectedUser() async {
        let repository = InMemorySettingsRepository(snapshot: .defaultValue)
        let themeStore = AppThemeStore()
        let tokenStore = InMemoryGitHubTokenStore()
        let oauthService = StubGitHubOAuthService(
            deviceCodeResult: .success(
                GitHubDeviceCode(
                    deviceCode: "device-code",
                    userCode: "ABCD-EFGH",
                    verificationURI: "https://github.com/login/device",
                    expiresIn: 600,
                    interval: 1
                )
            ),
            accessTokenResult: .success("access-token"),
            viewerResult: .success(
                GitHubAuthenticatedUser(
                    login: "octocat",
                    name: "The Octocat",
                    avatarURL: nil
                )
            )
        )

        let viewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: oauthService,
            gitHubTokenStore: tokenStore
        )
        viewModel.githubClientID = "client-id"

        await viewModel.loginWithGitHub()

        #expect(viewModel.isGitHubConnected)
        #expect(viewModel.githubAuthenticatedUser?.login == "octocat")
        #expect(tokenStore.token() == "access-token")
        #expect(viewModel.githubErrorMessage == nil)
    }
}

private final class InMemorySettingsRepository: SettingsRepository {
    private(set) var savedSnapshots: [SettingsSnapshot] = []
    private var currentSnapshot: SettingsSnapshot

    init(snapshot: SettingsSnapshot) {
        currentSnapshot = snapshot
    }

    func load() -> SettingsSnapshot {
        currentSnapshot
    }

    func save(_ snapshot: SettingsSnapshot) {
        currentSnapshot = snapshot
        savedSnapshots.append(snapshot)
    }
}

private struct StubGitHubOAuthService: GitHubOAuthServicing {
    var deviceCodeResult: Result<GitHubDeviceCode, Error> = .success(
        GitHubDeviceCode(
            deviceCode: "device-code",
            userCode: "ABCD-EFGH",
            verificationURI: "https://github.com/login/device",
            expiresIn: 600,
            interval: 1
        )
    )
    var accessTokenResult: Result<String, Error> = .success("access-token")
    var viewerResult: Result<GitHubAuthenticatedUser, Error> = .success(
        GitHubAuthenticatedUser(
            login: "octocat",
            name: "The Octocat",
            avatarURL: nil
        )
    )

    func requestDeviceCode(clientID: String, scope: String) async throws -> GitHubDeviceCode {
        try deviceCodeResult.get()
    }

    func pollAccessToken(clientID: String, deviceCode: String, interval: Int, expiresIn: Int) async throws -> String {
        try accessTokenResult.get()
    }

    func fetchViewer(accessToken: String) async throws -> GitHubAuthenticatedUser {
        try viewerResult.get()
    }
}

private final class InMemoryGitHubTokenStore: GitHubTokenStoring {
    private var storedToken: String?

    func token() -> String? {
        storedToken
    }

    func save(token: String) {
        storedToken = token
    }

    func clear() {
        storedToken = nil
    }
}
