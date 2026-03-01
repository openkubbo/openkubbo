import Foundation

struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool

    init(id: UUID = UUID(), title: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

struct TaskSnapshot: Codable, Equatable {
    var tasks: [TaskItem]

    static let defaultValue = TaskSnapshot(tasks: [])
}
