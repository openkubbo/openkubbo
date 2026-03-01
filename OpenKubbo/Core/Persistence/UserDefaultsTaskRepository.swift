import Foundation

final class UserDefaultsTaskRepository: TaskRepository {
    private enum Keys {
        static let taskSnapshot = "openkubbo.task.snapshot.v1"
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

    func load() -> TaskSnapshot {
        guard let data = userDefaults.data(forKey: Keys.taskSnapshot) else {
            return .defaultValue
        }

        guard let snapshot = try? decoder.decode(TaskSnapshot.self, from: data) else {
            return .defaultValue
        }

        return snapshot
    }

    func save(_ snapshot: TaskSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            assertionFailure("Failed to encode TaskSnapshot")
            return
        }

        userDefaults.set(data, forKey: Keys.taskSnapshot)
    }
}
