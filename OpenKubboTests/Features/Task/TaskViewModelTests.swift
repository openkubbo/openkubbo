import Foundation
import Testing
@testable import OpenKubbo

@MainActor
struct TaskViewModelTests {
    @Test
    func init_loadsTasksFromRepository() {
        let repository = InMemoryTaskRepository(
            snapshot: TaskSnapshot(
                tasks: [
                    TaskItem(title: "Existing", isDone: false)
                ]
            )
        )

        let viewModel = TaskViewModel(repository: repository)

        #expect(viewModel.tasks.count == 1)
        #expect(viewModel.tasks.first?.title == "Existing")
    }

    @Test
    func addTask_insertsAtTop_andPersists() {
        let repository = InMemoryTaskRepository(snapshot: .defaultValue)
        let viewModel = TaskViewModel(repository: repository)

        viewModel.draftTaskTitle = "  Nova tarefa  "
        viewModel.addTask()

        #expect(viewModel.tasks.count == 1)
        #expect(viewModel.tasks.first?.title == "Nova tarefa")
        #expect(viewModel.draftTaskTitle.isEmpty)
        #expect(repository.savedSnapshots.last?.tasks.count == 1)
    }

    @Test
    func toggleTaskCompletion_movesCompletedTaskToBottom() {
        let first = TaskItem(title: "Primeira", isDone: false)
        let second = TaskItem(title: "Segunda", isDone: false)
        let repository = InMemoryTaskRepository(
            snapshot: TaskSnapshot(tasks: [first, second])
        )
        let viewModel = TaskViewModel(repository: repository)

        viewModel.toggleTaskCompletion(for: first.id)

        #expect(viewModel.tasks.count == 2)
        #expect(viewModel.tasks[0].id == second.id)
        #expect(viewModel.tasks[1].id == first.id)
        #expect(viewModel.tasks[1].isDone)
    }

    @Test
    func movePendingTask_reordersOnlyPendingItems() {
        let first = TaskItem(title: "A", isDone: false)
        let second = TaskItem(title: "B", isDone: false)
        let done = TaskItem(title: "C", isDone: true)
        let repository = InMemoryTaskRepository(
            snapshot: TaskSnapshot(tasks: [first, second, done])
        )
        let viewModel = TaskViewModel(repository: repository)

        viewModel.movePendingTask(draggedTaskID: second.id, to: first.id)

        #expect(viewModel.tasks[0].id == second.id)
        #expect(viewModel.tasks[1].id == first.id)
        #expect(viewModel.tasks[2].id == done.id)
    }

    @Test
    func deleteTask_removesItem_andPersists() {
        let first = TaskItem(title: "A", isDone: false)
        let second = TaskItem(title: "B", isDone: false)
        let repository = InMemoryTaskRepository(
            snapshot: TaskSnapshot(tasks: [first, second])
        )
        let viewModel = TaskViewModel(repository: repository)

        viewModel.deleteTask(first.id)

        #expect(viewModel.tasks == [second])
        #expect(repository.savedSnapshots.last?.tasks == [second])
    }

    @Test
    func updateTaskTitle_ignoresEmptyTrimmedValue() {
        let first = TaskItem(title: "A", isDone: false)
        let repository = InMemoryTaskRepository(
            snapshot: TaskSnapshot(tasks: [first])
        )
        let viewModel = TaskViewModel(repository: repository)

        viewModel.updateTaskTitle(first.id, title: "   ")

        #expect(viewModel.tasks.first?.title == "A")
    }

    @Test
    func clearAllTasks_emptiesState_andPersistsSnapshot() {
        let repository = InMemoryTaskRepository(
            snapshot: TaskSnapshot(
                tasks: [
                    TaskItem(title: "A", isDone: false),
                    TaskItem(title: "B", isDone: false)
                ]
            )
        )
        let viewModel = TaskViewModel(repository: repository)
        viewModel.draftTaskTitle = "Draft"

        viewModel.clearAllTasks()

        #expect(viewModel.tasks.isEmpty)
        #expect(viewModel.draftTaskTitle.isEmpty)
        #expect(repository.savedSnapshots.last == .defaultValue)
    }
}

private final class InMemoryTaskRepository: TaskRepository {
    private(set) var savedSnapshots: [TaskSnapshot] = []
    private var currentSnapshot: TaskSnapshot

    init(snapshot: TaskSnapshot) {
        currentSnapshot = snapshot
    }

    func load() -> TaskSnapshot {
        currentSnapshot
    }

    func save(_ snapshot: TaskSnapshot) {
        currentSnapshot = snapshot
        savedSnapshots.append(snapshot)
    }
}
