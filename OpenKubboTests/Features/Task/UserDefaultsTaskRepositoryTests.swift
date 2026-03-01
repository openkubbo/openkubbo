import Foundation
import Testing
@testable import OpenKubbo

@MainActor
struct UserDefaultsTaskRepositoryTests {
    @Test
    func load_returnsDefaults_whenStorageIsEmpty() {
        let suiteName = "UserDefaultsTaskRepositoryTests.loadDefaults"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = UserDefaultsTaskRepository(userDefaults: defaults)

        #expect(repository.load() == .defaultValue)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test
    func save_thenLoad_roundTripsSnapshot() {
        let suiteName = "UserDefaultsTaskRepositoryTests.roundTrip"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let repository = UserDefaultsTaskRepository(userDefaults: defaults)
        let snapshot = TaskSnapshot(
            tasks: [
                TaskItem(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Task A", isDone: false),
                TaskItem(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Task B", isDone: true)
            ]
        )

        repository.save(snapshot)

        #expect(repository.load() == snapshot)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
