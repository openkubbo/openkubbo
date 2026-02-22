import Foundation

final class UserDefaultsSettingsRepository: SettingsRepository {
    private enum Keys {
        static let settingsSnapshot = "openkubbo.settings.snapshot.v1"
    }

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func load() -> SettingsSnapshot {
        guard let data = userDefaults.data(forKey: Keys.settingsSnapshot) else {
            return .defaultValue
        }

        guard let snapshot = try? decoder.decode(SettingsSnapshot.self, from: data) else {
            return .defaultValue
        }

        return snapshot
    }

    func save(_ snapshot: SettingsSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            assertionFailure("Failed to encode SettingsSnapshot")
            return
        }

        userDefaults.set(data, forKey: Keys.settingsSnapshot)
    }
}
