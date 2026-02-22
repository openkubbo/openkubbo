import Combine
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
    @Published var searchText = ""

    @Published var selectedThemeMode: ThemeMode {
        didSet {
            themeStore.apply(selectedThemeMode.appTheme)
            persist()
        }
    }

    @Published var launchAtLogin: Bool { didSet { persist() } }
    @Published var reopenPreviousWindows: Bool { didSet { persist() } }
    @Published var playCompletionSound: Bool { didSet { persist() } }
    @Published var hapticsEnabled: Bool { didSet { persist() } }
    @Published var appLanguage: String { didSet { persist() } }

    @Published var selectedAccentColorIndex: Int { didSet { persist() } }

    @Published var selectedModel: String { didSet { persist() } }
    @Published var temperature: Double { didSet { persist() } }
    @Published var terminalSuggestionsEnabled: Bool { didSet { persist() } }
    @Published var automaticErrorAnalysis: Bool { didSet { persist() } }
    @Published var syncProfilesEnabled: Bool { didSet { persist() } }

    @Published var githubClientID: String { didSet { persist() } }
    @Published private(set) var isGitHubAuthenticating = false
    @Published private(set) var githubStatusMessage = "Not connected."
    @Published private(set) var githubErrorMessage: String?
    @Published private(set) var githubUserCode: String?
    @Published private(set) var githubVerificationURL: URL?
    @Published private(set) var githubAuthenticatedUser: GitHubAuthenticatedUser?

    @Published private(set) var githubRepositories: [GitHubRepository] = []
    @Published private(set) var isGitHubLoadingRepositories = false
    @Published var githubTargetRepository = ""

    @Published var githubIssueTitle = ""
    @Published var githubIssueBody = ""
    @Published private(set) var isGitHubCreatingIssue = false

    @Published var githubPRTitle = ""
    @Published var githubPRBody = ""
    @Published var githubPRHead = ""
    @Published var githubPRBase = "main"
    @Published private(set) var isGitHubCreatingPR = false

    @Published var githubCommitPath = ""
    @Published var githubCommitMessage = ""
    @Published var githubCommitBranch = "main"
    @Published var githubCommitContent = ""
    @Published private(set) var isGitHubCommittingFile = false

    @Published private(set) var githubActionStatusMessage: String?
    @Published private(set) var githubActionErrorMessage: String?

    let executablePath = "/usr/local/bin/codex"
    let apiKeyMasked = "••••••••••••••••"
    let models = ["Gemini 1.5 Pro", "GPT-4.1", "Claude 3.7 Sonnet"]
    let languages = ["Português (Brasil)", "English (US)", "Español"]
    let shortcutGroups: [ShortcutGroup]

    private let repository: SettingsRepository
    private let themeStore: AppThemeStore
    private let gitHubOAuthService: GitHubOAuthServicing
    private let gitHubAPIService: GitHubAPIServicing
    private let gitHubTokenStore: GitHubTokenStoring

    private let gitHubOAuthScope = "repo read:org workflow gist"

    init(
        repository: SettingsRepository,
        themeStore: AppThemeStore,
        gitHubOAuthService: GitHubOAuthServicing,
        gitHubAPIService: GitHubAPIServicing,
        gitHubTokenStore: GitHubTokenStoring,
        shortcutGroups: [ShortcutGroup]? = nil
    ) {
        self.repository = repository
        self.themeStore = themeStore
        self.gitHubOAuthService = gitHubOAuthService
        self.gitHubAPIService = gitHubAPIService
        self.gitHubTokenStore = gitHubTokenStore
        self.shortcutGroups = shortcutGroups ?? ShortcutGroup.defaults

        let snapshot = repository.load()

        self.selectedThemeMode = ThemeMode(appTheme: snapshot.selectedTheme)

        self.launchAtLogin = snapshot.launchAtLogin
        self.reopenPreviousWindows = snapshot.reopenPreviousWindows
        self.playCompletionSound = snapshot.playCompletionSound
        self.hapticsEnabled = snapshot.hapticsEnabled
        self.appLanguage = snapshot.appLanguage

        self.selectedAccentColorIndex = snapshot.selectedAccentColorIndex

        self.selectedModel = snapshot.selectedModel
        self.temperature = snapshot.temperature
        self.terminalSuggestionsEnabled = snapshot.terminalSuggestionsEnabled
        self.automaticErrorAnalysis = snapshot.automaticErrorAnalysis
        self.syncProfilesEnabled = snapshot.syncProfilesEnabled

        self.githubClientID = snapshot.githubClientID ?? ""

        themeStore.apply(snapshot.selectedTheme)
        restoreGitHubSessionIfPossible()
    }

    var visibleTabs: [SettingsTab] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SettingsTab.allCases
        }

        return SettingsTab.allCases.filter { tab in
            tab.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var activeTab: SettingsTab {
        if visibleTabs.contains(selectedTab) {
            return selectedTab
        }

        return visibleTabs.first ?? .general
    }

    var isGitHubConnected: Bool {
        githubAuthenticatedUser != nil
    }

    var isGitHubBusy: Bool {
        isGitHubAuthenticating || isGitHubLoadingRepositories || isGitHubCreatingIssue || isGitHubCreatingPR || isGitHubCommittingFile
    }

    var githubDisplayName: String {
        if let name = githubAuthenticatedUser?.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        return githubAuthenticatedUser?.login ?? ""
    }

    var githubRepositorySuggestions: [String] {
        githubRepositories.map(\.fullName)
    }

    func selectTab(_ tab: SettingsTab) {
        selectedTab = tab
    }

    func clearSearch() {
        searchText = ""
    }

    func cycleThemeMode() {
        switch selectedThemeMode {
        case .light:
            selectedThemeMode = .dark
        case .dark:
            selectedThemeMode = .automatic
        case .automatic:
            selectedThemeMode = .light
        }
    }

    func loginWithGitHub() async {
        let clientID = githubClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            githubErrorMessage = "Enter your GitHub OAuth App Client ID."
            return
        }

        if isGitHubAuthenticating {
            return
        }

        githubErrorMessage = nil
        githubUserCode = nil
        githubVerificationURL = nil
        githubStatusMessage = "Requesting GitHub device code..."
        isGitHubAuthenticating = true

        defer {
            isGitHubAuthenticating = false
        }

        do {
            let deviceCode = try await gitHubOAuthService.requestDeviceCode(
                clientID: clientID,
                scope: gitHubOAuthScope
            )

            githubUserCode = deviceCode.userCode
            githubVerificationURL = URL(string: deviceCode.verificationURI)
            githubStatusMessage = "Click 'Open GitHub Device Page' and enter the code to continue."

            let accessToken = try await gitHubOAuthService.pollAccessToken(
                clientID: clientID,
                deviceCode: deviceCode.deviceCode,
                interval: deviceCode.interval,
                expiresIn: deviceCode.expiresIn
            )

            gitHubTokenStore.save(token: accessToken)

            let user = try await gitHubOAuthService.fetchViewer(accessToken: accessToken)
            githubAuthenticatedUser = user
            githubUserCode = nil
            githubVerificationURL = nil
            githubStatusMessage = "Connected as \(user.login)."

            await loadGitHubRepositories()
        } catch {
            gitHubTokenStore.clear()
            githubAuthenticatedUser = nil
            githubStatusMessage = "Not connected."
            githubRepositories = []

            githubErrorMessage = gitHubErrorDescription(error)
        }
    }

    func logoutGitHub() {
        gitHubTokenStore.clear()
        githubAuthenticatedUser = nil
        githubUserCode = nil
        githubVerificationURL = nil
        githubErrorMessage = nil
        githubStatusMessage = "Not connected."

        githubRepositories = []
        githubTargetRepository = ""
        githubIssueTitle = ""
        githubIssueBody = ""
        githubPRTitle = ""
        githubPRBody = ""
        githubPRHead = ""
        githubPRBase = "main"
        githubCommitPath = ""
        githubCommitMessage = ""
        githubCommitBranch = "main"
        githubCommitContent = ""
        githubActionStatusMessage = nil
        githubActionErrorMessage = nil
    }

    func loadGitHubRepositories() async {
        guard let token = prepareGitHubAction() else {
            return
        }

        if isGitHubLoadingRepositories {
            return
        }

        isGitHubLoadingRepositories = true
        defer {
            isGitHubLoadingRepositories = false
        }

        do {
            let repositories = try await gitHubAPIService.fetchRepositories(accessToken: token)
            githubRepositories = repositories
            updateDefaultRepositorySelection(with: repositories)

            if repositories.isEmpty {
                githubActionStatusMessage = "No repositories found for this account."
            } else {
                githubActionStatusMessage = "Loaded \(repositories.count) repositories."
            }
        } catch {
            githubActionErrorMessage = gitHubErrorDescription(error)
        }
    }

    func createGitHubIssue() async {
        guard let token = prepareGitHubAction() else {
            return
        }

        if isGitHubCreatingIssue {
            return
        }

        let repository = normalizedRepository()
        guard !repository.isEmpty else {
            githubActionErrorMessage = "Select a repository (owner/repo) for the issue."
            return
        }

        let title = githubIssueTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            githubActionErrorMessage = "Issue title is required."
            return
        }

        isGitHubCreatingIssue = true
        defer {
            isGitHubCreatingIssue = false
        }

        do {
            let issue = try await gitHubAPIService.createIssue(
                accessToken: token,
                repositoryFullName: repository,
                title: title,
                body: githubIssueBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : githubIssueBody
            )

            githubActionErrorMessage = nil
            githubActionStatusMessage = "Issue #\(issue.number) created in \(repository)."
            githubIssueTitle = ""
            githubIssueBody = ""
        } catch {
            githubActionErrorMessage = gitHubErrorDescription(error)
        }
    }

    func createGitHubPullRequest() async {
        guard let token = prepareGitHubAction() else {
            return
        }

        if isGitHubCreatingPR {
            return
        }

        let repository = normalizedRepository()
        guard !repository.isEmpty else {
            githubActionErrorMessage = "Select a repository (owner/repo) for the pull request."
            return
        }

        let title = githubPRTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = githubPRHead.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = githubPRBase.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            githubActionErrorMessage = "Pull request title is required."
            return
        }
        guard !head.isEmpty else {
            githubActionErrorMessage = "Head branch is required."
            return
        }
        guard !base.isEmpty else {
            githubActionErrorMessage = "Base branch is required."
            return
        }

        isGitHubCreatingPR = true
        defer {
            isGitHubCreatingPR = false
        }

        do {
            let pullRequest = try await gitHubAPIService.createPullRequest(
                accessToken: token,
                repositoryFullName: repository,
                title: title,
                body: githubPRBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : githubPRBody,
                head: head,
                base: base
            )

            githubActionErrorMessage = nil
            githubActionStatusMessage = "Pull request #\(pullRequest.number) created in \(repository)."
            githubPRTitle = ""
            githubPRBody = ""
        } catch {
            githubActionErrorMessage = gitHubErrorDescription(error)
        }
    }

    func commitGitHubFile() async {
        guard let token = prepareGitHubAction() else {
            return
        }

        if isGitHubCommittingFile {
            return
        }

        let repository = normalizedRepository()
        guard !repository.isEmpty else {
            githubActionErrorMessage = "Select a repository (owner/repo) for the commit."
            return
        }

        let path = githubCommitPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = githubCommitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = githubCommitBranch.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !path.isEmpty else {
            githubActionErrorMessage = "File path is required."
            return
        }
        guard !message.isEmpty else {
            githubActionErrorMessage = "Commit message is required."
            return
        }
        guard !branch.isEmpty else {
            githubActionErrorMessage = "Commit branch is required."
            return
        }
        guard !githubCommitContent.isEmpty else {
            githubActionErrorMessage = "File content is required."
            return
        }

        isGitHubCommittingFile = true
        defer {
            isGitHubCommittingFile = false
        }

        do {
            let commit = try await gitHubAPIService.commitFile(
                accessToken: token,
                repositoryFullName: repository,
                path: path,
                branch: branch,
                message: message,
                content: githubCommitContent
            )

            githubActionErrorMessage = nil
            githubActionStatusMessage = "Commit \(String(commit.sha.prefix(7))) created in \(repository)."
            githubCommitMessage = ""
        } catch {
            githubActionErrorMessage = gitHubErrorDescription(error)
        }
    }

    private func restoreGitHubSessionIfPossible() {
        guard let token = gitHubTokenStore.token(), !token.isEmpty else {
            return
        }

        githubStatusMessage = "Restoring GitHub session..."

        Task { [weak self] in
            guard let self else { return }

            do {
                let user = try await self.gitHubOAuthService.fetchViewer(accessToken: token)
                await MainActor.run {
                    self.githubAuthenticatedUser = user
                    self.githubStatusMessage = "Connected as \(user.login)."
                }
                await self.loadGitHubRepositories()
            } catch {
                self.gitHubTokenStore.clear()
                await MainActor.run {
                    self.githubAuthenticatedUser = nil
                    self.githubStatusMessage = "Not connected."
                    self.githubRepositories = []
                }
            }
        }
    }

    private func prepareGitHubAction() -> String? {
        guard isGitHubConnected else {
            githubActionErrorMessage = "Connect your GitHub account first."
            return nil
        }

        guard let token = currentGitHubAccessToken() else {
            githubActionErrorMessage = "GitHub session not found. Please login again."
            return nil
        }

        githubActionErrorMessage = nil
        githubActionStatusMessage = nil
        return token
    }

    private func currentGitHubAccessToken() -> String? {
        guard let token = gitHubTokenStore.token(), !token.isEmpty else {
            return nil
        }

        return token
    }

    private func normalizedRepository() -> String {
        let trimmed = githubTargetRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        if let first = githubRepositories.first {
            return first.fullName
        }

        return ""
    }

    private func updateDefaultRepositorySelection(with repositories: [GitHubRepository]) {
        guard let first = repositories.first else {
            return
        }

        if githubTargetRepository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            githubTargetRepository = first.fullName
        }

        if githubPRBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || githubPRBase == "main" {
            githubPRBase = first.defaultBranch
        }

        if githubCommitBranch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || githubCommitBranch == "main" {
            githubCommitBranch = first.defaultBranch
        }
    }

    private func gitHubErrorDescription(_ error: Error) -> String {
        if let oauthError = error as? GitHubOAuthError,
           let message = oauthError.errorDescription {
            return message
        }

        if let apiError = error as? GitHubAPIError,
           let message = apiError.errorDescription {
            return message
        }

        return error.localizedDescription
    }

    private func persist() {
        let normalizedGitHubClientID = githubClientID
            .trimmingCharacters(in: .whitespacesAndNewlines)

        repository.save(
            SettingsSnapshot(
                selectedTheme: selectedThemeMode.appTheme,
                launchAtLogin: launchAtLogin,
                reopenPreviousWindows: reopenPreviousWindows,
                playCompletionSound: playCompletionSound,
                hapticsEnabled: hapticsEnabled,
                appLanguage: appLanguage,
                selectedAccentColorIndex: selectedAccentColorIndex,
                selectedModel: selectedModel,
                temperature: temperature,
                terminalSuggestionsEnabled: terminalSuggestionsEnabled,
                automaticErrorAnalysis: automaticErrorAnalysis,
                syncProfilesEnabled: syncProfilesEnabled,
                githubClientID: normalizedGitHubClientID.isEmpty ? nil : normalizedGitHubClientID
            )
        )
    }
}
