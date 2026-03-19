import Combine
import Foundation

@MainActor
final class TaskViewModel: ObservableObject {
    struct RemovedTask {
        let task: TaskItem
        let index: Int
    }

    @Published var draftTaskTitle = ""
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var isGeneratingIdeaTasks = false
    @Published private(set) var ideaGenerationErrorMessage: String?

    private let repository: TaskRepository
    private let ideaGenerator: TaskIdeaGenerating?

    init(repository: TaskRepository, ideaGenerator: TaskIdeaGenerating? = nil) {
        self.repository = repository
        self.ideaGenerator = ideaGenerator
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
        _ = deleteTaskAndReturn(taskID)
    }

    @discardableResult
    func deleteTaskAndReturn(_ taskID: UUID) -> RemovedTask? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
            return nil
        }

        let removedTask = tasks.remove(at: index)
        persist()
        return RemovedTask(task: removedTask, index: index)
    }

    func restoreTask(_ task: TaskItem, at index: Int) {
        guard !tasks.contains(where: { $0.id == task.id }) else { return }

        let clampedIndex = min(max(index, 0), tasks.count)
        tasks.insert(task, at: clampedIndex)
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

    func clearAllTasks() {
        guard !tasks.isEmpty || !draftTaskTitle.isEmpty else { return }
        tasks = []
        draftTaskTitle = ""
        persist()
    }

    func clearIdeaGenerationError() {
        ideaGenerationErrorMessage = nil
    }

    func generateTasks(from idea: String) async -> Bool {
        let trimmedIdea = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdea.isEmpty else {
            ideaGenerationErrorMessage = "Describe an idea before generating tasks."
            return false
        }

        guard let ideaGenerator else {
            ideaGenerationErrorMessage = "Configure an AI provider in Settings > API Keys first."
            return false
        }

        guard !isGeneratingIdeaTasks else {
            return false
        }

        ideaGenerationErrorMessage = nil
        isGeneratingIdeaTasks = true

        defer {
            isGeneratingIdeaTasks = false
        }

        do {
            let generatedTitles = try await ideaGenerator.generateTasks(from: trimmedIdea)
            addGeneratedTasks(generatedTitles)
            return true
        } catch {
            ideaGenerationErrorMessage = error.localizedDescription
            return false
        }
    }

    private var trimmedDraftTitle: String {
        draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addGeneratedTasks(_ titles: [String]) {
        let newTasks = titles.map { TaskItem(title: $0, isDone: false) }
        tasks.insert(contentsOf: newTasks, at: 0)
        persist()
    }

    private func persist() {
        repository.save(TaskSnapshot(tasks: tasks))
    }
}
