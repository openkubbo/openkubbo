protocol SettingsRepository {
    func load() -> SettingsSnapshot
    func save(_ snapshot: SettingsSnapshot)
}
