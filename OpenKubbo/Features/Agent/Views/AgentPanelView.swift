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

    private let panelWidth: CGFloat = 420
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
        isDarkTheme ? Color(red: 0.06, green: 0.07, blue: 0.08) : Color(red: 0.985, green: 0.986, blue: 0.992)
    }

    private var mutedCardFillColor: Color {
        isDarkTheme ? .white.opacity(0.06) : .black.opacity(0.04)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.90) : .black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.60) : .black.opacity(0.48)
    }

    private var terminalChromeTextColor: Color {
        isDarkTheme ? .white.opacity(0.54) : .black.opacity(0.44)
    }

    private var canSendPrompt: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
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

            VStack(alignment: .leading, spacing: 14) {
                header
                sessionStatus
                transcriptCard
                composer
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

                Button(action: closeWindow) {
                    AgentHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
            }
        }
    }

    private var sessionStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isResponding ? accentColor : Color(red: 0.23, green: 0.73, blue: 0.41))
                .frame(width: 8, height: 8)

            Text(isResponding ? "Streaming response..." : "Interactive session ready")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Spacer(minLength: 0)

            Text("chat / terminal")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var transcriptCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.99, green: 0.37, blue: 0.33).opacity(isDarkTheme ? 0.92 : 0.78))
                Circle()
                    .fill(Color(red: 0.96, green: 0.74, blue: 0.24).opacity(isDarkTheme ? 0.92 : 0.78))
                Circle()
                    .fill(Color(red: 0.23, green: 0.73, blue: 0.41).opacity(isDarkTheme ? 0.92 : 0.78))
            }
            .frame(width: 44, alignment: .leading)
            .overlay(alignment: .trailing) {
                Text("agent.session")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(terminalChromeTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 60)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 38)
            .padding(.horizontal, 14)

            Rectangle()
                .fill(cardStrokeColor)
                .frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(consoleEntries) { entry in
                            AgentConsoleRow(
                                entry: entry,
                                isDarkTheme: isDarkTheme,
                                accentColor: accentColor,
                                cardStrokeColor: cardStrokeColor,
                                cardFillColor: cardFillColor,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor
                            )
                            .id(entry.id)
                        }

                        if isResponding {
                            AgentTypingIndicator(
                                isDarkTheme: isDarkTheme,
                                secondaryTextColor: secondaryTextColor
                            )
                            .id(typingIndicatorID)
                        }
                    }
                    .padding(14)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(terminalFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: 1)
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(">")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)

                TextField("Type a prompt or command...", text: $draftPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(primaryTextColor)
                    .focused($isPromptFocused)
                    .onSubmit(sendPrompt)

                Button(action: sendPrompt) {
                    Group {
                        if isResponding {
                            ProgressView()
                                .controlSize(.small)
                                .tint(primaryTextColor)
                        } else {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(primaryTextColor)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
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

            HStack(spacing: 8) {
                Text(isResponding ? "kubbo > processing input" : "enter to send")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Text("terminal-style composer")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isPromptFocused ? accentColor.opacity(0.68) : cardStrokeColor, lineWidth: 1)
                )
        )
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
            Prompt received. This view is now structured like a console chat, and the next step is wiring live agent actions so Kubbo can stream real results here for: "\(trimmedPrompt)".
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
            return "//"
        case .user:
            return "you >"
        case .agent:
            return "kubbo >"
        }
    }
}

private struct AgentConsoleEntry: Identifiable {
    let id = UUID()
    let role: AgentConsoleRole
    let text: String

    static let previewEntries: [AgentConsoleEntry] = [
        .init(role: .status, text: "Session booted. Workspace-aware prompts and streaming updates can live here."),
        .init(role: .agent, text: "Ready. The panel keeps Kubbo's floating look, but now behaves like a terminal chat."),
        .init(role: .user, text: "Show the latest repository context."),
        .init(role: .agent, text: "The UI is prepared for that flow. Once the backend is connected, answers can stream into this transcript.")
    ]
}

private struct AgentConsoleRow: View {
    let entry: AgentConsoleEntry
    let isDarkTheme: Bool
    let accentColor: Color
    let cardStrokeColor: Color
    let cardFillColor: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color

    private var rowFillColor: Color {
        switch entry.role {
        case .status:
            return .clear
        case .user:
            return accentColor.opacity(isDarkTheme ? 0.14 : 0.10)
        case .agent:
            return cardFillColor.opacity(isDarkTheme ? 0.92 : 0.80)
        }
    }

    private var rowStrokeColor: Color {
        switch entry.role {
        case .status:
            return .clear
        case .user:
            return accentColor.opacity(isDarkTheme ? 0.34 : 0.24)
        case .agent:
            return cardStrokeColor
        }
    }

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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.role.label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(labelColor)
                .frame(width: 56, alignment: .leading)
                .padding(.top, 1)

            Text(entry.text)
                .font(
                    .system(
                        size: entry.role == .status ? 12 : 13,
                        weight: entry.role == .status ? .semibold : .medium,
                        design: .monospaced
                    )
                )
                .foregroundStyle(entry.role == .status ? secondaryTextColor : primaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, entry.role == .status ? 0 : 12)
        .padding(.vertical, entry.role == .status ? 0 : 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(rowFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(rowStrokeColor, lineWidth: 1)
                )
        )
    }
}

private struct AgentTypingIndicator: View {
    let isDarkTheme: Bool
    let secondaryTextColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("kubbo >")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(secondaryTextColor.opacity(isDarkTheme ? 0.78 : 0.64))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 24, alignment: .center)
        }
        .padding(.vertical, 2)
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
