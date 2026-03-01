protocol TaskRepository {
    func load() -> TaskSnapshot
    func save(_ snapshot: TaskSnapshot)
}
