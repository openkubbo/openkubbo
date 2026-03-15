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
    @Published var codexAPIKeyInput = ""
    @Published private(set) var localRepositoriesRootPath: String?
    @Published private(set) var hasCodexAPIKey = false
    @Published private(set) var codexStatusMessage = ""
    @Published private(set) var codexExecutablePath: String?
    @Published private(set) var nodeExecutablePath: String?
    @Published private(set) var isGitHubAuthenticating = false
    @Published private(set) var githubStatusMessage = "Not connected."
    @Published private(set) var githubErrorMessage: String?
    @Published private(set) var githubUserCode: String?
    @Published private(set) var githubVerificationURL: URL?
    @Published private(set) var githubAuthenticatedUser: GitHubAuthenticatedUser?

    let languages = ["English (US)", "Portuguese (Brazil)", "Spanish"]
    let shortcutGroups: [ShortcutGroup]

    private let repository: SettingsRepository
    private let themeStore: AppThemeStore
    private let gitHubOAuthService: GitHubOAuthServicing
    private let gitHubTokenStore: GitHubTokenStoring
    private let codexAPIKeyStore: CodexAPIKeyStoring
    private let codexExecutableResolver: CodexCLIExecutableResolving
    private let nodeExecutableResolver: NodeRuntimeExecutableResolving
    private var codexExecutableBookmarkData: Data?
    private var nodeExecutableBookmarkData: Data?
    private var localRepositoriesRootBookmarkData: Data?

    private let gitHubOAuthScope = "repo read:org workflow gist"

    init(
        repository: SettingsRepository,
        themeStore: AppThemeStore,
        gitHubOAuthService: GitHubOAuthServicing,
        gitHubTokenStore: GitHubTokenStoring,
        codexAPIKeyStore: CodexAPIKeyStoring,
        codexExecutableResolver: CodexCLIExecutableResolving,
        nodeExecutableResolver: NodeRuntimeExecutableResolving,
        shortcutGroups: [ShortcutGroup]? = nil
    ) {
        self.repository = repository
        self.themeStore = themeStore
        self.gitHubOAuthService = gitHubOAuthService
        self.gitHubTokenStore = gitHubTokenStore
        self.codexAPIKeyStore = codexAPIKeyStore
        self.codexExecutableResolver = codexExecutableResolver
        self.nodeExecutableResolver = nodeExecutableResolver
        self.shortcutGroups = shortcutGroups ?? ShortcutGroup.defaults

        let snapshot = repository.load()

        self.selectedThemeMode = ThemeMode(appTheme: snapshot.selectedTheme)

        self.launchAtLogin = snapshot.launchAtLogin
        self.reopenPreviousWindows = snapshot.reopenPreviousWindows
        self.playCompletionSound = snapshot.playCompletionSound
        self.hapticsEnabled = snapshot.hapticsEnabled
        self.appLanguage = snapshot.appLanguage

        self.selectedAccentColorIndex = snapshot.selectedAccentColorIndex

        self.selectedModel = Self.normalizedCodexModelIdentifier(snapshot.selectedModel)
        self.temperature = snapshot.temperature
        self.terminalSuggestionsEnabled = snapshot.terminalSuggestionsEnabled
        self.automaticErrorAnalysis = snapshot.automaticErrorAnalysis
        self.syncProfilesEnabled = snapshot.syncProfilesEnabled

        self.githubClientID = snapshot.githubClientID ?? ""
        self.codexExecutablePath = snapshot.codexExecutablePath
        self.codexExecutableBookmarkData = snapshot.codexExecutableBookmarkData
        self.nodeExecutablePath = snapshot.nodeExecutablePath
        self.nodeExecutableBookmarkData = snapshot.nodeExecutableBookmarkData
        self.localRepositoriesRootPath = snapshot.localRepositoriesRootPath
        self.localRepositoriesRootBookmarkData = snapshot.localRepositoriesRootBookmarkData

        themeStore.apply(snapshot.selectedTheme)
        themeStore.applyAccentColorIndex(snapshot.selectedAccentColorIndex)
        refreshCodexCLIState()
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

    var resolvedCodexExecutablePath: String? {
        codexExecutablePath ?? codexExecutableResolver.resolveExecutablePath()
    }

    var resolvedNodeExecutablePath: String? {
        nodeExecutablePath ?? nodeExecutableResolver.resolveNodeExecutablePath()
    }

    var canSaveCodexAPIKey: Bool {
        !codexAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasCodexExecutableOverride: Bool {
        codexExecutablePath?.isEmpty == false && codexExecutableBookmarkData != nil
    }

    var hasNodeExecutableOverride: Bool {
        nodeExecutablePath?.isEmpty == false && nodeExecutableBookmarkData != nil
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

    func setCodexExecutable(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        codexExecutablePath = url.path
        codexExecutableBookmarkData = bookmarkData
        persist()
        refreshCodexCLIState(statusOverride: "Codex executable saved.")
    }

    func clearCodexExecutableOverride() {
        codexExecutablePath = nil
        codexExecutableBookmarkData = nil
        persist()
        refreshCodexCLIState()
    }

    func setNodeExecutable(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        nodeExecutablePath = url.path
        nodeExecutableBookmarkData = bookmarkData
        persist()
        refreshCodexCLIState(statusOverride: "Node.js runtime saved.")
    }

    func clearNodeExecutableOverride() {
        nodeExecutablePath = nil
        nodeExecutableBookmarkData = nil
        persist()
        refreshCodexCLIState()
    }

    func saveCodexAPIKey() {
        let trimmedAPIKey = codexAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            return
        }

        codexAPIKeyStore.save(apiKey: trimmedAPIKey)
        codexAPIKeyInput = ""
        refreshCodexCLIState(statusOverride: "OpenAI API key saved in Keychain.")
    }

    func clearCodexAPIKey() {
        codexAPIKeyStore.clear()
        codexAPIKeyInput = ""
        refreshCodexCLIState(statusOverride: "OpenAI API key removed.")
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

    private func refreshCodexCLIState(statusOverride: String? = nil) {
        hasCodexAPIKey = !(codexAPIKeyStore.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if let statusOverride {
            codexStatusMessage = statusOverride
            return
        }

        let resolvedCodexExecutablePath = resolvedCodexExecutablePath
        let resolvedNodeExecutablePath = resolvedNodeExecutablePath
        let requiresNodeRuntime = resolvedCodexExecutablePath?.lowercased().hasSuffix(".js") ?? false

        guard hasCodexAPIKey else {
            codexStatusMessage = "Save your OpenAI API key to enable task generation."
            return
        }

        if requiresNodeRuntime, resolvedNodeExecutablePath == nil {
            codexStatusMessage = "OpenAI API key saved. Codex CLI is optional here; if you want to test the local launcher, also choose `/usr/local/bin/node`."
            return
        }

        if let codexExecutablePath, !codexExecutablePath.isEmpty {
            if requiresNodeRuntime, let resolvedNodeExecutablePath {
                codexStatusMessage = "OpenAI API key saved. Local Codex CLI is configured at \(codexExecutablePath) with Node.js at \(resolvedNodeExecutablePath)."
                return
            }

            codexStatusMessage = "OpenAI API key saved. Local Codex CLI is configured at \(codexExecutablePath)."
            return
        }

        if let executablePath = resolvedCodexExecutablePath {
            if requiresNodeRuntime, let resolvedNodeExecutablePath {
                codexStatusMessage = "OpenAI API key saved. Task generation is ready. Local Codex CLI was also detected at \(executablePath) with Node.js at \(resolvedNodeExecutablePath)."
                return
            }

            codexStatusMessage = "OpenAI API key saved. Task generation is ready. Local Codex CLI was also detected at \(executablePath)."
            return
        }

        codexStatusMessage = "OpenAI API key saved. Task generation is ready."
    }

    private func persist() {
        let normalizedGitHubClientID = githubClientID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSelectedModel = Self.normalizedCodexModelIdentifier(selectedModel)

        repository.save(
            SettingsSnapshot(
                selectedTheme: selectedThemeMode.appTheme,
                launchAtLogin: launchAtLogin,
                reopenPreviousWindows: reopenPreviousWindows,
                playCompletionSound: playCompletionSound,
                hapticsEnabled: hapticsEnabled,
                appLanguage: appLanguage,
                selectedAccentColorIndex: selectedAccentColorIndex,
                selectedModel: normalizedSelectedModel,
                temperature: temperature,
                terminalSuggestionsEnabled: terminalSuggestionsEnabled,
                automaticErrorAnalysis: automaticErrorAnalysis,
                syncProfilesEnabled: syncProfilesEnabled,
                codexExecutablePath: codexExecutablePath,
                codexExecutableBookmarkData: codexExecutableBookmarkData,
                nodeExecutablePath: nodeExecutablePath,
                nodeExecutableBookmarkData: nodeExecutableBookmarkData,
                githubClientID: normalizedGitHubClientID.isEmpty ? nil : normalizedGitHubClientID,
                localRepositoriesRootPath: localRepositoriesRootPath,
                localRepositoriesRootBookmarkData: localRepositoriesRootBookmarkData
            )
        )
    }

    private static func normalizedCodexModelIdentifier(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        switch trimmedValue {
        case "Gemini 1.5 Pro", "Claude 3.7 Sonnet":
            return ""
        default:
            return trimmedValue
        }
    }
}
