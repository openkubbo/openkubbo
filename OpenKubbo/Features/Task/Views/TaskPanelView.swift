import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TaskPanelView: View {
    @ObservedObject var viewModel: TaskViewModel

    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var hostWindow: NSWindow?
    @State private var isWindowPinned = true
    @State private var editingTaskID: UUID?
    @State private var editingTaskTitle = ""
    @State private var draggedTaskID: UUID?
    @State private var lastDropTargetTaskID: UUID?
    @State private var pendingRemovedTask: TaskViewModel.RemovedTask?
    @State private var undoDeleteDismissTask: Task<Void, Never>?

    private let panelWidth: CGFloat = 340
    private let panelHeight: CGFloat = 493
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    private var isDarkTheme: Bool {
        themeStore.resolvedColorScheme(systemColorScheme: systemColorScheme) == .dark
    }

    private var accentColor: Color {
        themeStore.accentColor
    }

    private var panelFillColor: Color {
        isDarkTheme ? Color(red: 0.09, green: 0.09, blue: 0.10) : Color(red: 0.97, green: 0.97, blue: 0.98)
    }

    private var panelStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.08)
    }

    private var cardFillColor: Color {
        isDarkTheme ? Color(red: 0.13, green: 0.13, blue: 0.14) : .white
    }

    private var cardStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.90) : .black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.60) : .black.opacity(0.48)
    }

    private var mutedCardFillColor: Color {
        isDarkTheme ? .white.opacity(0.06) : .black.opacity(0.04)
    }

    private var pendingCount: Int {
        viewModel.pendingCount
    }

    private var completionRatio: Double {
        viewModel.completionRatio
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(panelFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(panelStrokeColor, lineWidth: 1)
                )
                .padding(.horizontal, panelHorizontalInset)
                .padding(.vertical, panelVerticalInset)

            VStack(spacing: 14) {
                header
                newTaskInput
                tasksList
                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .padding(.horizontal, panelHorizontalInset)
            .padding(.vertical, panelVerticalInset)
            .overlay(alignment: .top) {
                SettingsWindowDragRegion()
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
            }

            if pendingRemovedTask != nil {
                undoDeleteToast
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .padding(.horizontal, windowEdgePaddingX)
        .padding(.vertical, windowEdgePaddingY)
        .background(
            SettingsWindowConfigurator(
                targetSize: CGSize(
                    width: panelWidth + (windowEdgePaddingX * 2),
                    height: panelHeight + (windowEdgePaddingY * 2)
                ),
                minimumSize: CGSize(width: 360, height: 434),
                windowIdentifier: "openkubbo.task.window",
                windowLevel: .floating
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
                applyWindowLevel(window)
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow,
                  closingWindow === hostWindow
            else {
                return
            }

            resetTaskStateForClose()
        }
        .onDisappear {
            cancelUndoDeleteTimer()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("Kubbo Task")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .frame(height: 36, alignment: .center)

                Spacer()
            }
            .frame(height: 36)
            .background(SettingsWindowDragRegion())

            HStack(spacing: 8) {
                TaskHeaderIcon(symbol: "lightbulb", isDarkTheme: isDarkTheme)

                Button(action: toggleWindowPin) {
                    TaskHeaderIcon(
                        symbol: isWindowPinned ? "pin.fill" : "pin",
                        isDarkTheme: isDarkTheme,
                        isActive: isWindowPinned,
                        accentColor: accentColor
                    )
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
                .help(isWindowPinned ? "Unpin window" : "Pin window on top")

                Button(action: openEmptyTaskWindow) {
                    TaskHeaderIcon(
                        symbol: "square.on.square",
                        isDarkTheme: isDarkTheme,
                        symbolTint: accentColor
                    )
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
                .help("Open new Kubbo Task")

                Button(action: closeWindow) {
                    TaskHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
            }
        }
    }

    private var newTaskInput: some View {
        HStack(spacing: 8) {
            TextField("New simple task...", text: $viewModel.draftTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .onSubmit {
                    viewModel.addTask()
                }

            Button(action: viewModel.addTask) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cardFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(cardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canAddTask)
            .opacity(viewModel.canAddTask ? 1 : 0.55)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.tasks) { task in
                    taskRow(task)
                }
            }
            .padding(.vertical, 2)
            .background(TaskScrollBarVisibilityConfigurator())
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var undoDeleteToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(secondaryTextColor)

            Text("Task deleted. Undo?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)

            Spacer(minLength: 6)

            Button("Undo") {
                undoDeletedTask()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(isDarkTheme ? 0.20 : 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(accentColor.opacity(0.42), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(isDarkTheme ? 0.24 : 0.10), radius: 8, x: 0, y: 4)
    }

    private func taskRow(_ task: TaskItem) -> some View {
        let isDone = task.isDone
        let isEditing = editingTaskID == task.id

        return HStack(alignment: .top, spacing: 12) {
            reorderHandle(for: task, isDone: isDone)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.toggleTaskCompletion(for: task.id)
                }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDone ? accentColor : secondaryTextColor.opacity(0.65))
            }
            .buttonStyle(.plain)
            .disabled(isEditing)

            Group {
                if isEditing {
                    TextField("Edit task", text: $editingTaskTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .submitLabel(.done)
                        .onSubmit {
                            saveTaskEdition(task.id)
                        }
                } else {
                    Text(task.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isDone ? secondaryTextColor : primaryTextColor)
                        .strikethrough(isDone, color: secondaryTextColor.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                Button {
                    if isEditing {
                        saveTaskEdition(task.id)
                    } else {
                        beginTaskEdition(task)
                    }
                } label: {
                    TaskRowActionIcon(symbol: isEditing ? "checkmark" : "pencil", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
                .help(isEditing ? "Save changes" : "Edit task")

                Button {
                    if isEditing {
                        cancelTaskEdition()
                    } else {
                        deleteTask(task.id)
                    }
                } label: {
                    TaskRowActionIcon(symbol: isEditing ? "xmark" : "trash", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
                .help(isEditing ? "Cancel editing" : "Delete task")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isDone ? mutedCardFillColor : cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
        .modifier(
            TaskRowDragModifier(
                taskID: task.id,
                isEnabled: !isDone && !isEditing,
                draggedTaskID: $draggedTaskID,
                lastDropTargetTaskID: $lastDropTargetTaskID
            )
        )
        .onDrop(
            of: [UTType.text],
            delegate: TaskRowDropDelegate(
                targetTaskID: task.id,
                targetTaskIsDone: isDone,
                canReorderTask: { taskID in
                    viewModel.canReorderTask(taskID: taskID)
                },
                moveTask: { draggedID, targetID in
                    viewModel.movePendingTask(draggedTaskID: draggedID, to: targetID)
                },
                draggedTaskID: $draggedTaskID,
                lastDropTargetTaskID: $lastDropTargetTaskID
            )
        )
    }

    @ViewBuilder
    private func reorderHandle(for task: TaskItem, isDone: Bool) -> some View {
        if isDone {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor.opacity(0.25))
                .padding(.top, 4)
        } else {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor.opacity(0.42))
                .padding(.top, 4)
                .taskCursorOnHover()
                .help("Reorder task")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(cardStrokeColor)
                .frame(height: 1)

            HStack {
                Text("\(pendingCount) pending")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Text("\(Int((completionRatio * 100).rounded()))% completed")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
            .frame(height: 22)
        }
        .padding(.top, 4)
    }

    private func beginTaskEdition(_ task: TaskItem) {
        editingTaskID = task.id
        editingTaskTitle = task.title
    }

    private func saveTaskEdition(_ taskID: UUID) {
        viewModel.updateTaskTitle(taskID, title: editingTaskTitle)
        cancelTaskEdition()
    }

    private func cancelTaskEdition() {
        editingTaskID = nil
        editingTaskTitle = ""
    }

    private func deleteTask(_ taskID: UUID) {
        var removedTask: TaskViewModel.RemovedTask?
        withAnimation(.easeInOut(duration: 0.16)) {
            removedTask = viewModel.deleteTaskAndReturn(taskID)
            pendingRemovedTask = removedTask
        }

        guard removedTask != nil else {
            return
        }

        if draggedTaskID == taskID {
            draggedTaskID = nil
        }

        if editingTaskID == taskID {
            cancelTaskEdition()
        }

        scheduleUndoDeleteTimeout()
    }

    private func closeWindow() {
        resetTaskStateForClose()
        hostWindow?.close()
    }

    private func toggleWindowPin() {
        isWindowPinned.toggle()
        applyWindowLevel(hostWindow)
    }

    private func openEmptyTaskWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "task-empty")
    }

    private func resetTaskStateForClose() {
        cancelUndoDeleteTimer()
        pendingRemovedTask = nil
        viewModel.clearAllTasks()
        draggedTaskID = nil
        lastDropTargetTaskID = nil
        cancelTaskEdition()
    }

    private func undoDeletedTask() {
        guard let pendingRemovedTask else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            viewModel.restoreTask(pendingRemovedTask.task, at: pendingRemovedTask.index)
            self.pendingRemovedTask = nil
        }

        cancelUndoDeleteTimer()
    }

    private func scheduleUndoDeleteTimeout() {
        cancelUndoDeleteTimer()
        undoDeleteDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.16)) {
                    pendingRemovedTask = nil
                }
                undoDeleteDismissTask = nil
            }
        }
    }

    private func cancelUndoDeleteTimer() {
        undoDeleteDismissTask?.cancel()
        undoDeleteDismissTask = nil
    }

    private func applyWindowLevel(_ window: NSWindow?) {
        guard let window else { return }
        window.level = isWindowPinned ? .floating : .normal
    }

    private struct TaskRowDropDelegate: DropDelegate {
        let targetTaskID: UUID
        let targetTaskIsDone: Bool
        let canReorderTask: (UUID) -> Bool
        let moveTask: (UUID, UUID) -> Void
        @Binding var draggedTaskID: UUID?
        @Binding var lastDropTargetTaskID: UUID?

        func validateDrop(info: DropInfo) -> Bool {
            guard !targetTaskIsDone, let draggedTaskID else {
                return false
            }

            return canReorderTask(draggedTaskID)
        }

        func dropEntered(info: DropInfo) {
            guard !targetTaskIsDone,
                  let draggedTaskID,
                  draggedTaskID != targetTaskID,
                  canReorderTask(draggedTaskID),
                  canReorderTask(targetTaskID),
                  lastDropTargetTaskID != targetTaskID
            else {
                return
            }

            lastDropTargetTaskID = targetTaskID
            withAnimation(.easeOut(duration: 0.10)) {
                moveTask(draggedTaskID, targetTaskID)
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggedTaskID = nil
            lastDropTargetTaskID = nil
            return true
        }
    }

    private struct TaskRowDragModifier: ViewModifier {
        let taskID: UUID
        let isEnabled: Bool
        @Binding var draggedTaskID: UUID?
        @Binding var lastDropTargetTaskID: UUID?

        @ViewBuilder
        func body(content: Content) -> some View {
            if isEnabled {
                content.onDrag {
                    draggedTaskID = taskID
                    lastDropTargetTaskID = nil
                    return NSItemProvider(object: taskID.uuidString as NSString)
                }
            } else {
                content
            }
        }
    }
}

private struct TaskRowActionIcon: View {
    let symbol: String
    var isDarkTheme: Bool = false

    private var symbolColor: Color {
        isDarkTheme ? .white.opacity(0.60) : .black.opacity(0.54)
    }

    private var fillColor: Color {
        isDarkTheme ? .white.opacity(0.05) : .black.opacity(0.03)
    }

    private var strokeColor: Color {
        isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.10)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
    }
}

private struct TaskHeaderIcon: View {
    let symbol: String
    var isDarkTheme: Bool = false
    var isActive: Bool = false
    var accentColor: Color = Color(red: 0.39, green: 0.44, blue: 0.99)
    var symbolTint: Color?

    private var symbolColor: Color {
        if isActive {
            return .white.opacity(0.94)
        }
        if let symbolTint {
            return symbolTint.opacity(isDarkTheme ? 0.94 : 0.88)
        }
        return isDarkTheme ? .white.opacity(0.62) : .black.opacity(0.56)
    }

    private var fillColor: Color {
        if isActive {
            return accentColor
        }
        return isDarkTheme ? Color(red: 0.20, green: 0.20, blue: 0.21) : .white
    }

    private var strokeColor: Color {
        if isActive {
            return accentColor.opacity(isDarkTheme ? 0.72 : 0.64)
        }
        return isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.10)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(fillColor)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
    }
}

private struct TaskCursorOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func taskCursorOnHover() -> some View {
        modifier(TaskCursorOnHover())
    }
}

private struct TaskScrollBarVisibilityConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = nsView.enclosingScrollView else {
                return
            }

            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.scrollerStyle = .legacy
            scrollView.autohidesScrollers = true
        }
    }
}
