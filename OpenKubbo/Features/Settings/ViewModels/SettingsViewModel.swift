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

    let executablePath = "/usr/local/bin/codex"
    let apiKeyMasked = "••••••••••••••••"
    let models = ["Gemini 1.5 Pro", "GPT-4.1", "Claude 3.7 Sonnet"]
    let languages = ["Português (Brasil)", "English (US)", "Español"]
    let shortcutGroups: [ShortcutGroup]

    private let repository: SettingsRepository
    private let themeStore: AppThemeStore

    init(
        repository: SettingsRepository,
        themeStore: AppThemeStore,
        shortcutGroups: [ShortcutGroup]? = nil
    ) {
        self.repository = repository
        self.themeStore = themeStore
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

        themeStore.apply(snapshot.selectedTheme)
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

    private func persist() {
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
                syncProfilesEnabled: syncProfilesEnabled
            )
        )
    }
}
