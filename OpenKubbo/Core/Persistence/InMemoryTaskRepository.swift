final class InMemoryTaskRepository: TaskRepository {
    private var snapshot: TaskSnapshot

    init(snapshot: TaskSnapshot = .defaultValue) {
        self.snapshot = snapshot
    }

    func load() -> TaskSnapshot {
        snapshot
    }

    func save(_ snapshot: TaskSnapshot) {
        self.snapshot = snapshot
    }
}
