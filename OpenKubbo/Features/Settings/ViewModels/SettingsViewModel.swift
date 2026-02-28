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

    @Published var selectedAccentColorIndex: Int {
        didSet {
            themeStore.applyAccentColorIndex(selectedAccentColorIndex)
            persist()
        }
    }

    @Published var selectedModel: String { didSet { persist() } }
    @Published var temperature: Double { didSet { persist() } }
    @Published var terminalSuggestionsEnabled: Bool { didSet { persist() } }
    @Published var automaticErrorAnalysis: Bool { didSet { persist() } }
    @Published var syncProfilesEnabled: Bool { didSet { persist() } }

    @Published var githubClientID: String { didSet { persist() } }
    @Published private(set) var localRepositoriesRootPath: String?
    @Published private(set) var isGitHubAuthenticating = false
    @Published private(set) var githubStatusMessage = "Not connected."
    @Published private(set) var githubErrorMessage: String?
    @Published private(set) var githubUserCode: String?
    @Published private(set) var githubVerificationURL: URL?
    @Published private(set) var githubAuthenticatedUser: GitHubAuthenticatedUser?

    let executablePath = "/usr/local/bin/codex"
    let apiKeyMasked = "••••••••••••••••"
    let models = ["Gemini 1.5 Pro", "GPT-4.1", "Claude 3.7 Sonnet"]
    let languages = ["Português (Brasil)", "English (US)", "Español"]
    let shortcutGroups: [ShortcutGroup]

    private let repository: SettingsRepository
    private let themeStore: AppThemeStore
    private let gitHubOAuthService: GitHubOAuthServicing
    private let gitHubTokenStore: GitHubTokenStoring
    private var localRepositoriesRootBookmarkData: Data?

    private let gitHubOAuthScope = "repo read:org workflow gist"

    init(
        repository: SettingsRepository,
        themeStore: AppThemeStore,
        gitHubOAuthService: GitHubOAuthServicing,
        gitHubTokenStore: GitHubTokenStoring,
        shortcutGroups: [ShortcutGroup]? = nil
    ) {
        self.repository = repository
        self.themeStore = themeStore
        self.gitHubOAuthService = gitHubOAuthService
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
        self.localRepositoriesRootPath = snapshot.localRepositoriesRootPath
        self.localRepositoriesRootBookmarkData = snapshot.localRepositoriesRootBookmarkData

        themeStore.apply(snapshot.selectedTheme)
        themeStore.applyAccentColorIndex(snapshot.selectedAccentColorIndex)
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
        isGitHubAuthenticating
    }

    var githubDisplayName: String {
        if let name = githubAuthenticatedUser?.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        return githubAuthenticatedUser?.login ?? ""
    }

    var hasLocalRepositoriesRootConfigured: Bool {
        localRepositoriesRootPath?.isEmpty == false && localRepositoriesRootBookmarkData != nil
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

    func setLocalRepositoriesRoot(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        localRepositoriesRootPath = url.path
        localRepositoriesRootBookmarkData = bookmarkData
        persist()
    }

    func clearLocalRepositoriesRoot() {
        localRepositoriesRootPath = nil
        localRepositoriesRootBookmarkData = nil
        persist()
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
        } catch {
            gitHubTokenStore.clear()
            githubAuthenticatedUser = nil
            githubStatusMessage = "Not connected."

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
            } catch {
                self.gitHubTokenStore.clear()
                await MainActor.run {
                    self.githubAuthenticatedUser = nil
                    self.githubStatusMessage = "Not connected."
                }
            }
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
                githubClientID: normalizedGitHubClientID.isEmpty ? nil : normalizedGitHubClientID,
                localRepositoriesRootPath: localRepositoriesRootPath,
                localRepositoriesRootBookmarkData: localRepositoriesRootBookmarkData
            )
        )
    }
}
