import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TaskPanelView: View {
    private struct TaskItem: Identifiable {
        let id = UUID()
        var title: String
        var isDone: Bool
    }

    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var hostWindow: NSWindow?
    @State private var isWindowPinned = true
    @State private var draftTaskTitle = ""
    @State private var draggedTaskID: UUID?
    @State private var tasks: [TaskItem] = []

    private let panelWidth: CGFloat = 340
    private let panelHeight: CGFloat = 704
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
        tasks.filter { !$0.isDone }.count
    }

    private var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter(\.isDone).count
        return Double(completed) / Double(tasks.count)
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
                minimumSize: CGSize(width: 360, height: 620),
                windowIdentifier: "openkubbo.task.window",
                windowLevel: .floating
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
                applyWindowLevel(window)
            }
        )
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
                .help(isWindowPinned ? "Desafixar janela" : "Fixar janela no topo")

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
            TextField("Nova tarefa simples...", text: $draftTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Button(action: addTask) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(cardFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(cardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func taskRow(_ task: TaskItem) -> some View {
        let isDone = task.isDone

        return HStack(alignment: .top, spacing: 12) {
            reorderHandle(for: task, isDone: isDone)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    toggleTaskCompletion(for: task.id)
                }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDone ? accentColor : secondaryTextColor.opacity(0.65))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isDone ? secondaryTextColor : primaryTextColor)
                .strikethrough(isDone, color: secondaryTextColor.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                Button(action: {}) {
                    TaskRowActionIcon(symbol: "pencil", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
                .help("Editar tarefa")

                Button(action: {}) {
                    TaskRowActionIcon(symbol: "trash", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .taskCursorOnHover()
                .help("Deletar tarefa")
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
                isEnabled: !isDone,
                draggedTaskID: $draggedTaskID
            )
        )
        .onDrop(
            of: [UTType.text],
            delegate: TaskRowDropDelegate(
                targetTaskID: task.id,
                targetTaskIsDone: isDone,
                tasks: $tasks,
                draggedTaskID: $draggedTaskID
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
                .help("Reordenar tarefa")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(cardStrokeColor)
                .frame(height: 1)

            HStack {
                Text("\(pendingCount) pendentes")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Text("\(Int((completionRatio * 100).rounded()))% concluido")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
            .frame(height: 22)
        }
        .padding(.top, 4)
    }

    private func addTask() {
        let trimmed = draftTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            tasks.insert(TaskItem(title: trimmed, isDone: false), at: 0)
            draftTaskTitle = ""
        }
    }

    private func toggleTaskCompletion(for taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        let wasDone = tasks[index].isDone
        tasks[index].isDone.toggle()

        guard wasDone == false, tasks[index].isDone else { return }
        let completedTask = tasks.remove(at: index)
        tasks.append(completedTask)
    }

    private func closeWindow() {
        hostWindow?.close()
    }

    private func toggleWindowPin() {
        isWindowPinned.toggle()
        applyWindowLevel(hostWindow)
    }

    private func applyWindowLevel(_ window: NSWindow?) {
        guard let window else { return }
        window.level = isWindowPinned ? .floating : .normal
    }

    private struct TaskRowDropDelegate: DropDelegate {
        let targetTaskID: UUID
        let targetTaskIsDone: Bool
        @Binding var tasks: [TaskItem]
        @Binding var draggedTaskID: UUID?

        func validateDrop(info: DropInfo) -> Bool {
            guard !targetTaskIsDone,
                  let draggedTaskID,
                  let draggedIndex = tasks.firstIndex(where: { $0.id == draggedTaskID })
            else {
                return false
            }

            return !tasks[draggedIndex].isDone
        }

        func dropEntered(info: DropInfo) {
            guard !targetTaskIsDone,
                  let draggedTaskID,
                  draggedTaskID != targetTaskID,
                  let fromIndex = tasks.firstIndex(where: { $0.id == draggedTaskID }),
                  let toIndex = tasks.firstIndex(where: { $0.id == targetTaskID }),
                  !tasks[fromIndex].isDone,
                  !tasks[toIndex].isDone
            else {
                return
            }

            guard fromIndex != toIndex else { return }

            withAnimation(.easeInOut(duration: 0.12)) {
                let movedTask = tasks.remove(at: fromIndex)
                tasks.insert(movedTask, at: toIndex)
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            draggedTaskID = nil
            return true
        }
    }

    private struct TaskRowDragModifier: ViewModifier {
        let taskID: UUID
        let isEnabled: Bool
        @Binding var draggedTaskID: UUID?

        @ViewBuilder
        func body(content: Content) -> some View {
            if isEnabled {
                content.onDrag {
                    draggedTaskID = taskID
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

    private var symbolColor: Color {
        if isActive {
            return .white.opacity(0.94)
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
