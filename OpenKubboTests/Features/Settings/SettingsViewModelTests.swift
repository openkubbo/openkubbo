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

        let viewModel = SettingsViewModel(repository: repository, themeStore: themeStore)

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

        let viewModel = SettingsViewModel(repository: repository, themeStore: themeStore)
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

        let viewModel = SettingsViewModel(repository: repository, themeStore: themeStore)
        viewModel.searchText = "Codex"

        #expect(viewModel.visibleTabs == [.codexCLI])
        #expect(viewModel.activeTab == .codexCLI)
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
