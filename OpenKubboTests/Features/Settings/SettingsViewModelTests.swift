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
            gitHubAPIService: StubGitHubAPIService(),
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
            gitHubAPIService: StubGitHubAPIService(),
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
            gitHubAPIService: StubGitHubAPIService(),
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
            gitHubAPIService: StubGitHubAPIService(),
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
            gitHubAPIService: StubGitHubAPIService(),
            gitHubTokenStore: tokenStore
        )
        viewModel.githubClientID = "client-id"

        await viewModel.loginWithGitHub()

        #expect(viewModel.isGitHubConnected)
        #expect(viewModel.githubAuthenticatedUser?.login == "octocat")
        #expect(tokenStore.token() == "access-token")
        #expect(viewModel.githubErrorMessage == nil)
        #expect(!viewModel.githubRepositories.isEmpty)
        #expect(viewModel.githubTargetRepository == "octocat/openkubbo")
    }

    @Test
    func createGitHubIssue_createsIssue_whenConnectedAndDataIsValid() async {
        let repository = InMemorySettingsRepository(snapshot: .defaultValue)
        let themeStore = AppThemeStore()
        let tokenStore = InMemoryGitHubTokenStore()
        let apiService = StubGitHubAPIService(
            issueResult: .success(
                GitHubIssueSummary(
                    number: 42,
                    title: "Issue Title",
                    htmlURL: nil
                )
            )
        )

        let viewModel = SettingsViewModel(
            repository: repository,
            themeStore: themeStore,
            gitHubOAuthService: StubGitHubOAuthService(),
            gitHubAPIService: apiService,
            gitHubTokenStore: tokenStore
        )
        viewModel.githubClientID = "client-id"
        await viewModel.loginWithGitHub()

        viewModel.githubTargetRepository = "octocat/openkubbo"
        viewModel.githubIssueTitle = "Issue Title"
        viewModel.githubIssueBody = "Issue body"

        await viewModel.createGitHubIssue()

        #expect(viewModel.githubActionErrorMessage == nil)
        #expect(viewModel.githubActionStatusMessage?.contains("Issue #42") == true)
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

private struct StubGitHubAPIService: GitHubAPIServicing {
    var repositoriesResult: Result<[GitHubRepository], Error> = .success(
        [
            GitHubRepository(
                id: "octocat/openkubbo",
                name: "openkubbo",
                fullName: "octocat/openkubbo",
                ownerLogin: "octocat",
                isPrivate: false,
                defaultBranch: "main",
                htmlURL: nil
            )
        ]
    )
    var issueResult: Result<GitHubIssueSummary, Error> = .success(
        GitHubIssueSummary(
            number: 1,
            title: "Issue",
            htmlURL: nil
        )
    )
    var pullRequestResult: Result<GitHubPullRequestSummary, Error> = .success(
        GitHubPullRequestSummary(
            number: 1,
            title: "PR",
            htmlURL: nil
        )
    )
    var commitResult: Result<GitHubCommitSummary, Error> = .success(
        GitHubCommitSummary(
            sha: "abcdef123456",
            message: "Commit",
            htmlURL: nil
        )
    )

    func fetchRepositories(accessToken: String) async throws -> [GitHubRepository] {
        try repositoriesResult.get()
    }

    func createIssue(accessToken: String, repositoryFullName: String, title: String, body: String?) async throws -> GitHubIssueSummary {
        try issueResult.get()
    }

    func createPullRequest(
        accessToken: String,
        repositoryFullName: String,
        title: String,
        body: String?,
        head: String,
        base: String
    ) async throws -> GitHubPullRequestSummary {
        try pullRequestResult.get()
    }

    func commitFile(
        accessToken: String,
        repositoryFullName: String,
        path: String,
        branch: String,
        message: String,
        content: String
    ) async throws -> GitHubCommitSummary {
        try commitResult.get()
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
