import Combine
import Foundation

@MainActor
final class TaskViewModel: ObservableObject {
    @Published var draftTaskTitle = ""
    @Published private(set) var tasks: [TaskItem]

    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
        self.tasks = repository.load().tasks
    }

    var pendingCount: Int {
        tasks.filter { !$0.isDone }.count
    }

    var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter(\.isDone).count
        return Double(completedCount) / Double(tasks.count)
    }

    var canAddTask: Bool {
        !trimmedDraftTitle.isEmpty
    }

    func addTask() {
        guard canAddTask else { return }

        tasks.insert(TaskItem(title: trimmedDraftTitle, isDone: false), at: 0)
        draftTaskTitle = ""
        persist()
    }

    func toggleTaskCompletion(for taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        let wasDone = tasks[index].isDone
        tasks[index].isDone.toggle()

        if !wasDone && tasks[index].isDone {
            let completedTask = tasks.remove(at: index)
            tasks.append(completedTask)
        }

        persist()
    }

    func deleteTask(_ taskID: UUID) {
        let oldCount = tasks.count
        tasks.removeAll { $0.id == taskID }

        guard tasks.count != oldCount else { return }
        persist()
    }

    func updateTaskTitle(_ taskID: UUID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let index = tasks.firstIndex(where: { $0.id == taskID })
        else {
            return
        }

        guard tasks[index].title != trimmedTitle else { return }
        tasks[index].title = trimmedTitle
        persist()
    }

    func canReorderTask(taskID: UUID) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }
        return !task.isDone
    }

    func movePendingTask(draggedTaskID: UUID, to targetTaskID: UUID) {
        guard draggedTaskID != targetTaskID,
              let fromIndex = tasks.firstIndex(where: { $0.id == draggedTaskID }),
              let toIndex = tasks.firstIndex(where: { $0.id == targetTaskID }),
              !tasks[fromIndex].isDone,
              !tasks[toIndex].isDone
        else {
            return
        }

        let movedTask = tasks.remove(at: fromIndex)
        tasks.insert(movedTask, at: toIndex)
        persist()
    }

    private var trimmedDraftTitle: String {
        draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persist() {
        repository.save(TaskSnapshot(tasks: tasks))
    }
}
