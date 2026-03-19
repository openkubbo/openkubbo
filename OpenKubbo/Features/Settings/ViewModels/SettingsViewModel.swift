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

    @Published var taskGenerationProvider: TaskGenerationProvider {
        didSet {
            persist()
            refreshProviderStates()
        }
    }
    @Published var selectedModel: String { didSet { persist() } }
    @Published var geminiSelectedModel: String { didSet { persist() } }
    @Published var temperature: Double { didSet { persist() } }
    @Published var terminalSuggestionsEnabled: Bool { didSet { persist() } }
    @Published var automaticErrorAnalysis: Bool { didSet { persist() } }
    @Published var syncProfilesEnabled: Bool { didSet { persist() } }

    @Published var githubClientID: String { didSet { persist() } }
    @Published var codexAPIKeyInput = ""
    @Published var geminiAPIKeyInput = ""
    @Published private(set) var localRepositoriesRootPath: String?
    @Published private(set) var hasCodexAPIKey = false
    @Published private(set) var hasGeminiAPIKey = false
    @Published private(set) var codexStatusMessage = ""
    @Published private(set) var geminiStatusMessage = ""
    @Published private(set) var codexExecutablePath: String?
    @Published private(set) var geminiExecutablePath: String?
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
    private let geminiAPIKeyStore: GeminiAPIKeyStoring
    private let codexExecutableResolver: CodexCLIExecutableResolving
    private let geminiExecutableResolver: GeminiCLIExecutableResolving
    private let nodeExecutableResolver: NodeRuntimeExecutableResolving
    private var codexExecutableBookmarkData: Data?
    private var geminiExecutableBookmarkData: Data?
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
        geminiAPIKeyStore: GeminiAPIKeyStoring,
        geminiExecutableResolver: GeminiCLIExecutableResolving,
        nodeExecutableResolver: NodeRuntimeExecutableResolving,
        shortcutGroups: [ShortcutGroup]? = nil
    ) {
        self.repository = repository
        self.themeStore = themeStore
        self.gitHubOAuthService = gitHubOAuthService
        self.gitHubTokenStore = gitHubTokenStore
        self.codexAPIKeyStore = codexAPIKeyStore
        self.geminiAPIKeyStore = geminiAPIKeyStore
        self.codexExecutableResolver = codexExecutableResolver
        self.geminiExecutableResolver = geminiExecutableResolver
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

        self.taskGenerationProvider = snapshot.taskGenerationProvider
        self.selectedModel = Self.normalizedModelIdentifier(snapshot.selectedModel)
        self.geminiSelectedModel = Self.normalizedModelIdentifier(snapshot.geminiSelectedModel)
        self.temperature = snapshot.temperature
        self.terminalSuggestionsEnabled = snapshot.terminalSuggestionsEnabled
        self.automaticErrorAnalysis = snapshot.automaticErrorAnalysis
        self.syncProfilesEnabled = snapshot.syncProfilesEnabled

        self.githubClientID = snapshot.githubClientID ?? ""
        self.codexExecutablePath = snapshot.codexExecutablePath
        self.codexExecutableBookmarkData = snapshot.codexExecutableBookmarkData
        self.geminiExecutablePath = snapshot.geminiExecutablePath
        self.geminiExecutableBookmarkData = snapshot.geminiExecutableBookmarkData
        self.nodeExecutablePath = snapshot.nodeExecutablePath
        self.nodeExecutableBookmarkData = snapshot.nodeExecutableBookmarkData
        self.localRepositoriesRootPath = snapshot.localRepositoriesRootPath
        self.localRepositoriesRootBookmarkData = snapshot.localRepositoriesRootBookmarkData

        themeStore.apply(snapshot.selectedTheme)
        themeStore.applyAccentColorIndex(snapshot.selectedAccentColorIndex)
        refreshProviderStates()
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

    var resolvedGeminiExecutablePath: String? {
        geminiExecutablePath ?? geminiExecutableResolver.resolveExecutablePath()
    }

    var resolvedNodeExecutablePath: String? {
        nodeExecutablePath ?? nodeExecutableResolver.resolveNodeExecutablePath()
    }

    var canSaveCodexAPIKey: Bool {
        !codexAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSaveGeminiAPIKey: Bool {
        !geminiAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasCodexExecutableOverride: Bool {
        codexExecutablePath?.isEmpty == false && codexExecutableBookmarkData != nil
    }

    var hasGeminiExecutableOverride: Bool {
        geminiExecutablePath?.isEmpty == false && geminiExecutableBookmarkData != nil
    }

    var hasNodeExecutableOverride: Bool {
        nodeExecutablePath?.isEmpty == false && nodeExecutableBookmarkData != nil
    }

    private var canLaunchLocalCLI: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
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

    func setGeminiExecutable(url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        geminiExecutablePath = url.path
        geminiExecutableBookmarkData = bookmarkData
        persist()
        refreshGeminiCLIState(statusOverride: "Gemini executable saved.")
    }

    func clearGeminiExecutableOverride() {
        geminiExecutablePath = nil
        geminiExecutableBookmarkData = nil
        persist()
        refreshGeminiCLIState()
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
        refreshProviderStates(
            codexStatusOverride: "Node.js runtime saved.",
            geminiStatusOverride: "Node.js runtime saved."
        )
    }

    func clearNodeExecutableOverride() {
        nodeExecutablePath = nil
        nodeExecutableBookmarkData = nil
        persist()
        refreshProviderStates()
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

    func saveGeminiAPIKey() {
        let trimmedAPIKey = geminiAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            return
        }

        geminiAPIKeyStore.save(apiKey: trimmedAPIKey)
        geminiAPIKeyInput = ""
        refreshGeminiCLIState(statusOverride: "Gemini API key saved in Keychain.")
    }

    func clearGeminiAPIKey() {
        geminiAPIKeyStore.clear()
        geminiAPIKeyInput = ""
        refreshGeminiCLIState(statusOverride: "Gemini API key removed.")
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

    private func refreshProviderStates(
        codexStatusOverride: String? = nil,
        geminiStatusOverride: String? = nil
    ) {
        refreshCodexCLIState(statusOverride: codexStatusOverride)
        refreshGeminiCLIState(statusOverride: geminiStatusOverride)
    }

    private func refreshCodexCLIState(statusOverride: String? = nil) {
        hasCodexAPIKey = !(codexAPIKeyStore.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if let statusOverride {
            codexStatusMessage = statusOverride
            return
        }

        let resolvedExecutablePath = resolvedCodexExecutablePath
        let resolvedNodeExecutablePath = resolvedNodeExecutablePath
        let requiresNodeRuntime = resolvedExecutablePath?.lowercased().hasSuffix(".js") ?? false

        if let codexExecutablePath, !codexExecutablePath.isEmpty {
            if requiresNodeRuntime, resolvedNodeExecutablePath == nil {
                codexStatusMessage = "Codex CLI is configured at \(codexExecutablePath), but this launcher still needs Node.js. Choose `/usr/local/bin/node`."
                return
            }

            if requiresNodeRuntime, let resolvedNodeExecutablePath {
                codexStatusMessage = canLaunchLocalCLI
                    ? "Codex CLI is ready at \(codexExecutablePath) with Node.js at \(resolvedNodeExecutablePath). In Terminal, run `codex login` and choose ChatGPT."
                    : "Codex CLI is configured at \(codexExecutablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Codex session."
                return
            }

            codexStatusMessage = canLaunchLocalCLI
                ? "Codex CLI is ready at \(codexExecutablePath). In Terminal, run `codex login` and choose ChatGPT."
                : "Codex CLI is configured at \(codexExecutablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Codex session."
            return
        }

        if let executablePath = resolvedExecutablePath {
            if requiresNodeRuntime, resolvedNodeExecutablePath == nil {
                codexStatusMessage = "Codex CLI was detected at \(executablePath), but this launcher still needs Node.js. Choose `/usr/local/bin/node`."
                return
            }

            if requiresNodeRuntime, let resolvedNodeExecutablePath {
                codexStatusMessage = canLaunchLocalCLI
                    ? "Codex CLI was detected at \(executablePath) with Node.js at \(resolvedNodeExecutablePath). In Terminal, run `codex login` and choose ChatGPT."
                    : "Codex CLI was detected at \(executablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Codex session."
                return
            }

            codexStatusMessage = canLaunchLocalCLI
                ? "Codex CLI was detected at \(executablePath). In Terminal, run `codex login` and choose ChatGPT."
                : "Codex CLI was detected at \(executablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Codex session."
            return
        }

        if hasCodexAPIKey {
            codexStatusMessage = "No local Codex CLI was detected. Task generation will use the saved OpenAI API key."
            return
        }

        codexStatusMessage = "Install Codex CLI and run `codex login`, or save an OpenAI API key as fallback."
    }

    private func refreshGeminiCLIState(statusOverride: String? = nil) {
        hasGeminiAPIKey = !(geminiAPIKeyStore.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if let statusOverride {
            geminiStatusMessage = statusOverride
            return
        }

        let resolvedExecutablePath = resolvedGeminiExecutablePath
        let resolvedNodeExecutablePath = resolvedNodeExecutablePath
        let requiresNodeRuntime = resolvedExecutablePath?.lowercased().hasSuffix(".js") ?? false

        if let geminiExecutablePath, !geminiExecutablePath.isEmpty {
            if requiresNodeRuntime, resolvedNodeExecutablePath == nil {
                geminiStatusMessage = "Gemini CLI is configured at \(geminiExecutablePath), but this launcher still needs Node.js. Choose `/usr/local/bin/node`."
                return
            }

            if requiresNodeRuntime, let resolvedNodeExecutablePath {
                geminiStatusMessage = canLaunchLocalCLI
                    ? "Gemini CLI is ready at \(geminiExecutablePath) with Node.js at \(resolvedNodeExecutablePath). In Terminal, run `gemini` and sign in with Google."
                    : "Gemini CLI is configured at \(geminiExecutablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Gemini session."
                return
            }

            geminiStatusMessage = canLaunchLocalCLI
                ? "Gemini CLI is ready at \(geminiExecutablePath). In Terminal, run `gemini` and sign in with Google."
                : "Gemini CLI is configured at \(geminiExecutablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Gemini session."
            return
        }

        if let executablePath = resolvedExecutablePath {
            if requiresNodeRuntime, resolvedNodeExecutablePath == nil {
                geminiStatusMessage = "Gemini CLI was detected at \(executablePath), but this launcher still needs Node.js. Choose `/usr/local/bin/node`."
                return
            }

            if requiresNodeRuntime, let resolvedNodeExecutablePath {
                geminiStatusMessage = canLaunchLocalCLI
                    ? "Gemini CLI was detected at \(executablePath) with Node.js at \(resolvedNodeExecutablePath). In Terminal, run `gemini` and sign in with Google."
                    : "Gemini CLI was detected at \(executablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Gemini session."
                return
            }

            geminiStatusMessage = canLaunchLocalCLI
                ? "Gemini CLI was detected at \(executablePath). In Terminal, run `gemini` and sign in with Google."
                : "Gemini CLI was detected at \(executablePath), but this sandboxed build cannot launch it. Run the Debug build from Xcode to use your local Gemini session."
            return
        }

        if hasGeminiAPIKey {
            geminiStatusMessage = "No local Gemini CLI was detected. Kubbo will still pass the saved Gemini API key to the CLI when it is available."
            return
        }

        geminiStatusMessage = "Install Gemini CLI and run `gemini` to sign in, or save a Gemini API key for headless auth."
    }

    private func persist() {
        let normalizedGitHubClientID = githubClientID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSelectedModel = Self.normalizedModelIdentifier(selectedModel)
        let normalizedGeminiSelectedModel = Self.normalizedModelIdentifier(geminiSelectedModel)

        repository.save(
            SettingsSnapshot(
                selectedTheme: selectedThemeMode.appTheme,
                launchAtLogin: launchAtLogin,
                reopenPreviousWindows: reopenPreviousWindows,
                playCompletionSound: playCompletionSound,
                hapticsEnabled: hapticsEnabled,
                appLanguage: appLanguage,
                selectedAccentColorIndex: selectedAccentColorIndex,
                taskGenerationProvider: taskGenerationProvider,
                selectedModel: normalizedSelectedModel,
                geminiSelectedModel: normalizedGeminiSelectedModel,
                temperature: temperature,
                terminalSuggestionsEnabled: terminalSuggestionsEnabled,
                automaticErrorAnalysis: automaticErrorAnalysis,
                syncProfilesEnabled: syncProfilesEnabled,
                codexExecutablePath: codexExecutablePath,
                codexExecutableBookmarkData: codexExecutableBookmarkData,
                geminiExecutablePath: geminiExecutablePath,
                geminiExecutableBookmarkData: geminiExecutableBookmarkData,
                nodeExecutablePath: nodeExecutablePath,
                nodeExecutableBookmarkData: nodeExecutableBookmarkData,
                githubClientID: normalizedGitHubClientID.isEmpty ? nil : normalizedGitHubClientID,
                localRepositoriesRootPath: localRepositoriesRootPath,
                localRepositoriesRootBookmarkData: localRepositoriesRootBookmarkData
            )
        )
    }

    private static func normalizedModelIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
