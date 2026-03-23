import AppKit
import SwiftUI

struct AgentPanelView: View {
    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var hostWindow: NSWindow?
    @State private var isWindowPinned = true
    @State private var draftPrompt = ""
    @State private var consoleEntries = AgentConsoleEntry.previewEntries
    @State private var isResponding = false
    @State private var responseTask: Task<Void, Never>?
    @FocusState private var isPromptFocused: Bool

    private let panelWidth: CGFloat = 430
    private let panelHeight: CGFloat = 560
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12
    private let typingIndicatorID = "agent.typing.indicator"

    private var isDarkTheme: Bool {
        themeStore.resolvedColorScheme(systemColorScheme: systemColorScheme) == .dark
    }

    private var accentColor: Color {
        themeStore.accentColor
    }

    private var panelFillColor: Color {
        isDarkTheme ? Color(red: 0.08, green: 0.09, blue: 0.10) : Color(red: 0.975, green: 0.978, blue: 0.984)
    }

    private var panelStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.12) : .black.opacity(0.08)
    }

    private var chromeFillColor: Color {
        isDarkTheme ? Color(red: 0.11, green: 0.12, blue: 0.13) : Color(red: 0.94, green: 0.945, blue: 0.955)
    }

    private var promptFillColor: Color {
        isDarkTheme ? Color(red: 0.09, green: 0.10, blue: 0.11) : Color(red: 0.965, green: 0.968, blue: 0.976)
    }

    private var dividerColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.07)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.90) : .black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.58) : .black.opacity(0.48)
    }

    private var tertiaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.42) : .black.opacity(0.34)
    }

    private var canSendPrompt: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    private var sessionStatusText: String {
        isResponding ? "session busy" : "session ready"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(panelFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(panelStrokeColor, lineWidth: 1)
                )
                .padding(.horizontal, panelHorizontalInset)
                .padding(.vertical, panelVerticalInset)

            VStack(spacing: 0) {
                terminalToolbar

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                transcriptView

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                promptBar
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, panelHorizontalInset)
            .padding(.vertical, panelVerticalInset)
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
                minimumSize: CGSize(width: 400, height: 520),
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

    private var terminalToolbar: some View {
        ZStack {
            SettingsWindowDragRegion()

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.99, green: 0.37, blue: 0.33).opacity(isDarkTheme ? 0.92 : 0.78))
                    Circle()
                        .fill(Color(red: 0.96, green: 0.74, blue: 0.24).opacity(isDarkTheme ? 0.92 : 0.78))
                    Circle()
                        .fill(Color(red: 0.23, green: 0.73, blue: 0.41).opacity(isDarkTheme ? 0.92 : 0.78))
                }
                .frame(width: 42, alignment: .leading)

                Text("Kubbo Agent")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(primaryTextColor)

                Spacer(minLength: 0)

                Text(sessionStatusText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isResponding ? accentColor : secondaryTextColor)

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

                Button(action: closeWindow) {
                    AgentHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help("Close window")
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 48)
        .background(chromeFillColor)
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    statusLine

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
                .padding(.bottom, 20)
            }
            .scrollIndicators(.visible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(panelFillColor)
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
    }

    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("kubbo@agent % interactive chat shell")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(primaryTextColor)

            Text("The panel itself is the terminal now. Messages and prompt render directly in the shell.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(tertiaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private var promptBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
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
                    .frame(height: 28)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                canSendPrompt
                                    ? accentColor.opacity(isDarkTheme ? 0.88 : 0.76)
                                    : dividerColor.opacity(isDarkTheme ? 0.70 : 0.85)
                            )
                    )
                }
                .buttonStyle(.plain)
                .agentCursorOnHover(isEnabled: canSendPrompt)
                .disabled(!canSendPrompt)
            }

            Text(isResponding ? "kubbo > processing prompt..." : "press enter to send")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(promptFillColor)
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
            Prompt received. The shell layout is now applied to the full panel, so the next step is connecting real agent output directly into this transcript for: "\(trimmedPrompt)".
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
        .init(role: .status, text: "Session booted in terminal mode."),
        .init(role: .agent, text: "Ready. The shell is now the main panel, not a nested terminal component."),
        .init(role: .user, text: "Show the latest repository context."),
        .init(role: .agent, text: "The transcript is prepared for that flow. Live repository-aware output can be streamed directly here.")
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
                .frame(width: 48, alignment: .leading)

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
                .frame(width: 48, alignment: .leading)

            Text("processing...")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
        }
    }
}

private struct AgentHeaderIcon: View {
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
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: 30, height: 30)
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
