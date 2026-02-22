import Foundation
import Testing
@testable import OpenKubbo

struct UserDefaultsSettingsRepositoryTests {
    @Test
    func load_returnsDefaults_whenStorageIsEmpty() {
        let suiteName = "UserDefaultsSettingsRepositoryTests.loadDefaults"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = UserDefaultsSettingsRepository(userDefaults: defaults)

        #expect(repository.load() == .defaultValue)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func save_thenLoad_roundTripsSnapshot() {
        let suiteName = "UserDefaultsSettingsRepositoryTests.roundTrip"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = UserDefaultsSettingsRepository(userDefaults: defaults)
        let snapshot = SettingsSnapshot(
            selectedTheme: .dark,
            launchAtLogin: true,
            reopenPreviousWindows: false,
            playCompletionSound: false,
            hapticsEnabled: false,
            appLanguage: "English (US)",
            selectedAccentColorIndex: 3,
            selectedModel: "GPT-4.1",
            temperature: 0.3,
            terminalSuggestionsEnabled: false,
            automaticErrorAnalysis: true,
            syncProfilesEnabled: false
        )

        repository.save(snapshot)

        #expect(repository.load() == snapshot)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
