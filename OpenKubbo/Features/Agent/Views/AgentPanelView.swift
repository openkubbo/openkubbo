import AppKit
import SwiftUI

struct AgentPanelView: View {
    @ObservedObject var taskViewModel: TaskViewModel

    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var hostWindow: NSWindow?
    @State private var isWindowPinned = true
    @State private var draftPrompt = ""
    @State private var consoleEntries = AgentConsoleEntry.previewEntries
    @State private var isResponding = false
    @State private var responseTask: Task<Void, Never>?
    @FocusState private var isPromptFocused: Bool

    private let panelWidth: CGFloat = 920
    private let panelHeight: CGFloat = 560
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12
    private let typingIndicatorID = "agent.typing.indicator"
    private let terminalColumnWidth: CGFloat = 558
    private let contentColumnSpacing: CGFloat = 16

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

    private var terminalFillColor: Color {
        isDarkTheme ? Color(red: 0.10, green: 0.10, blue: 0.11) : Color(red: 0.985, green: 0.986, blue: 0.992)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.90) : .black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.60) : .black.opacity(0.48)
    }

    private var tertiaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.42) : .black.opacity(0.34)
    }

    private var mutedCardFillColor: Color {
        isDarkTheme ? .white.opacity(0.06) : .black.opacity(0.04)
    }

    private var dividerColor: Color {
        isDarkTheme ? .white.opacity(0.08) : .black.opacity(0.06)
    }

    private var canSendPrompt: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    private var taskCompletionText: String {
        "\(Int((taskViewModel.completionRatio * 100).rounded()))% completed"
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
                sessionStrip
                contentColumns
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
                minimumSize: CGSize(width: 920, height: 520),
                windowIdentifier: "openkubbo.agent.window",
                windowLevel: .floating
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
                applyWindowLevel(window)
            }
        )
        .onAppear {
            isPromptFocused = true
        }
        .onDisappear {
            cancelPendingResponse()
        }
    }

    private var contentColumns: some View {
        HStack(alignment: .top, spacing: contentColumnSpacing) {
            terminalSurface
                .frame(width: terminalColumnWidth)

            taskPreviewPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("Kubbo Agent")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .frame(height: 36, alignment: .center)

                Spacer()
            }
            .frame(height: 36)
            .background(SettingsWindowDragRegion())

            HStack(spacing: 8) {
                Button(action: toggleWindowPin) {
                    AgentHeaderIcon(
                        symbol: isWindowPinned ? "pin.fill" : "pin",
                        isDarkTheme: isDarkTheme,
                        isActive: isWindowPinned,
                        accentColor: accentColor
                    )
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help(isWindowPinned ? "Unpin window" : "Pin window on top")

                Button(action: openEmptyAgentWindow) {
                    AgentHeaderIcon(
                        symbol: "square.on.square",
                        isDarkTheme: isDarkTheme,
                        symbolTint: accentColor
                    )
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help("Open new Kubbo Agent")

                Button(action: closeWindow) {
                    AgentHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
            }
        }
    }

    private var sessionStrip: some View {
        HStack(spacing: 10) {
            Text("Shell")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(mutedCardFillColor)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 1)
                        )
                )

            Circle()
                .fill(isResponding ? accentColor : Color(red: 0.23, green: 0.73, blue: 0.41))
                .frame(width: 8, height: 8)

            Text(isResponding ? "Streaming response..." : "Terminal session ready")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(primaryTextColor)

            Spacer(minLength: 0)

            Text("chat + terminal")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var terminalSurface: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        shellIntro

                        ForEach(consoleEntries) { entry in
                            AgentConsoleRow(
                                entry: entry,
                                accentColor: accentColor,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor
                            )
                            .id(entry.id)
                        }

                        if isResponding {
                            AgentTypingIndicator(secondaryTextColor: secondaryTextColor)
                                .id(typingIndicatorID)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(terminalFillColor)
                .onAppear {
                    scrollToBottom(with: proxy)
                }
                .onChange(of: consoleEntries.count) {
                    scrollToBottom(with: proxy)
                }
                .onChange(of: isResponding) {
                    scrollToBottom(with: proxy)
                }
            }

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            promptComposer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(terminalFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var shellIntro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("kubbo@agent % interactive chat shell")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(primaryTextColor)

            Text("Task layout on the outside, terminal flow on the inside.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(tertiaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 2)
    }

    private var promptComposer: some View {
        HStack(spacing: 10) {
            Text("kubbo@agent %")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor)

            TextField("Type a prompt or command...", text: $draftPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(primaryTextColor)
                .focused($isPromptFocused)
                .onSubmit(sendPrompt)

            Button(action: sendPrompt) {
                HStack(spacing: 6) {
                    if isResponding {
                        ProgressView()
                            .controlSize(.small)
                            .tint(primaryTextColor)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }

                    Text(isResponding ? "run" : "send")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(canSendPrompt || isResponding ? primaryTextColor : secondaryTextColor)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            canSendPrompt
                                ? accentColor.opacity(isDarkTheme ? 0.88 : 0.78)
                                : mutedCardFillColor
                        )
                )
            }
            .buttonStyle(.plain)
            .agentCursorOnHover(isEnabled: canSendPrompt)
            .disabled(!canSendPrompt)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardFillColor.opacity(isDarkTheme ? 0.52 : 0.70))
    }

    private var taskPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("Task")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)

                Spacer(minLength: 0)

                AgentHeaderIcon(symbol: "lightbulb", isDarkTheme: isDarkTheme, size: 32)
                    .allowsHitTesting(false)
            }
            .frame(height: 36)

            taskPreviewInput

            taskPreviewList

            Rectangle()
                .fill(cardStrokeColor)
                .frame(height: 1)

            HStack {
                Text("\(taskViewModel.pendingCount) pending")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Text(taskCompletionText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
            .frame(height: 22)
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(terminalFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: 1)
        )
    }

    private var taskPreviewInput: some View {
        HStack(spacing: 8) {
            TextField("New simple task...", text: $taskViewModel.draftTaskTitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundStyle(primaryTextColor)
                .onSubmit(addSidebarTask)

            Button(action: addSidebarTask) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(terminalFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(cardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!taskViewModel.canAddTask)
            .opacity(taskViewModel.canAddTask ? 1 : 0.55)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFillColor.opacity(isDarkTheme ? 0.72 : 0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var taskPreviewList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(taskViewModel.tasks) { task in
                    sidebarTaskRow(task)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func closeWindow() {
        cancelPendingResponse()
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

    private func openEmptyAgentWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "agent-empty")
    }

    private func addSidebarTask() {
        withAnimation(.easeInOut(duration: 0.16)) {
            taskViewModel.addTask()
        }
    }

    private func toggleSidebarTask(_ taskID: UUID) {
        withAnimation(.easeInOut(duration: 0.18)) {
            taskViewModel.toggleTaskCompletion(for: taskID)
        }
    }

    private func deleteSidebarTask(_ taskID: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            taskViewModel.deleteTask(taskID)
        }
    }

    private func sidebarTaskRow(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                toggleSidebarTask(task.id)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(task.isDone ? accentColor : secondaryTextColor.opacity(0.65))
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(task.isDone ? secondaryTextColor : primaryTextColor)
                .strikethrough(task.isDone, color: secondaryTextColor.opacity(0.9))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                deleteSidebarTask(task.id)
            } label: {
                AgentTaskRowActionIcon(isDarkTheme: isDarkTheme, secondaryTextColor: secondaryTextColor)
            }
            .buttonStyle(.plain)
            .agentCursorOnHover()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(task.isDone ? mutedCardFillColor : cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private func sendPrompt() {
        let trimmedPrompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !isResponding else { return }

        draftPrompt = ""
        consoleEntries.append(.init(role: .user, text: trimmedPrompt))
        isResponding = true

        responseTask?.cancel()
        responseTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }

            let responseText = """
            Prompt received. This version keeps the same overall structure as Task, while the main content area behaves like a terminal transcript for: "\(trimmedPrompt)".
            """

            await MainActor.run {
                consoleEntries.append(.init(role: .agent, text: responseText))
                isResponding = false
                responseTask = nil
                isPromptFocused = true
            }
        }
    }

    private func cancelPendingResponse() {
        responseTask?.cancel()
        responseTask = nil
        isResponding = false
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                if isResponding {
                    proxy.scrollTo(typingIndicatorID, anchor: .bottom)
                } else if let lastEntryID = consoleEntries.last?.id {
                    proxy.scrollTo(lastEntryID, anchor: .bottom)
                }
            }
        }
    }
}

private enum AgentConsoleRole {
    case status
    case user
    case agent

    var label: String {
        switch self {
        case .status:
            return "sys"
        case .user:
            return "you"
        case .agent:
            return "kubbo"
        }
    }
}

private struct AgentConsoleEntry: Identifiable {
    let id = UUID()
    let role: AgentConsoleRole
    let text: String

    static let previewEntries: [AgentConsoleEntry] = [
        .init(role: .status, text: "Session booted in task-style shell mode."),
        .init(role: .agent, text: "Ready. The panel layout now matches Task more closely, but the transcript still behaves like a terminal."),
        .init(role: .user, text: "Show the latest repository context."),
        .init(role: .agent, text: "The shell area is prepared for that flow. Live repository-aware output can be streamed directly here.")
    ]
}

private struct AgentConsoleRow: View {
    let entry: AgentConsoleEntry
    let accentColor: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color

    private var labelColor: Color {
        switch entry.role {
        case .status:
            return secondaryTextColor
        case .user:
            return accentColor
        case .agent:
            return primaryTextColor
        }
    }

    private var messageColor: Color {
        entry.role == .status ? secondaryTextColor : primaryTextColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.role.label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(labelColor)
                .frame(width: 44, alignment: .leading)

            Text(verbatim: entry.text)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(messageColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AgentTypingIndicator: View {
    let secondaryTextColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("kubbo")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 44, alignment: .leading)

            Text("processing...")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
        }
    }
}

private struct AgentTaskRowActionIcon: View {
    let isDarkTheme: Bool
    let secondaryTextColor: Color

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(secondaryTextColor)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            )
    }
}

private struct AgentHeaderIcon: View {
    let symbol: String
    var isDarkTheme: Bool = false
    var isActive: Bool = false
    var accentColor: Color = Color(red: 0.39, green: 0.44, blue: 0.99)
    var symbolTint: Color?
    var size: CGFloat = 36

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
            .frame(width: size, height: size)
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

private struct AgentCursorOnHover: ViewModifier {
    var isEnabled = true

    func body(content: Content) -> some View {
        content.onHover { isHovering in
            guard isEnabled else { return }

            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func agentCursorOnHover(isEnabled: Bool = true) -> some View {
        modifier(AgentCursorOnHover(isEnabled: isEnabled))
    }
}
