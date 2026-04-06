import AppKit
import SwiftUI

struct AgentPanelView: View {
    @ObservedObject var taskViewModel: TaskViewModel
    @AppStorage("openkubbo.settings.snapshot.v1") private var settingsSnapshotData = Data()

    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var hostWindow: NSWindow?
    @State private var isWindowPinned = true
    @State private var draftPrompt = ""
    @State private var consoleEntries = AgentConsoleEntry.previewEntries
    @State private var cliOverride: AgentCLIProvider?
    @State private var isIdeaComposerPresented = false
    @State private var ideaPrompt = ""
    @State private var editingTaskID: UUID?
    @State private var editingTaskTitle = ""
    @State private var pendingRemovedTask: TaskViewModel.RemovedTask?
    @State private var isResponding = false
    @State private var responseTask: Task<Void, Never>?
    @State private var undoDeleteDismissTask: Task<Void, Never>?
    @State private var cliSessionIdentifiers: [AgentCLIProvider: String] = [:]
    @State private var selectedSessionPersona: AgentSessionPersona = .tars
    @FocusState private var isPromptFocused: Bool
    @FocusState private var isIdeaPromptFocused: Bool

    private let cliService = AgentCLIService()

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

    private var mutedCardFillColor: Color {
        isDarkTheme ? .white.opacity(0.06) : .black.opacity(0.04)
    }

    private var dividerColor: Color {
        isDarkTheme ? .white.opacity(0.08) : .black.opacity(0.06)
    }

    private var canSendPrompt: Bool {
        !draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    private var canGenerateIdeaCards: Bool {
        !ideaPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var settingsSnapshot: SettingsSnapshot {
        guard !settingsSnapshotData.isEmpty,
              let snapshot = try? JSONDecoder().decode(SettingsSnapshot.self, from: settingsSnapshotData)
        else {
            return .defaultValue
        }

        return snapshot
    }

    private var configuredCLIProvider: AgentCLIProvider {
        switch settingsSnapshot.taskGenerationProvider {
        case .openAI:
            return .codex
        case .google:
            return .gemini
        }
    }

    private var activeCLIProvider: AgentCLIProvider {
        cliOverride ?? configuredCLIProvider
    }

    private var smartTaskProviderLabel: String {
        activeCLIProvider.displayName
    }

    private var taskCompletionText: String {
        "\(Int((taskViewModel.completionRatio * 100).rounded()))% completed"
    }

    private func personaColor(for persona: AgentSessionPersona) -> Color {
        switch persona {
        case .tars:
            return Color(red: 0.23, green: 0.52, blue: 0.96)
        case .kipp:
            return Color(red: 0.96, green: 0.79, blue: 0.20)
        case .case:
            return Color(red: 0.24, green: 0.72, blue: 0.44)
        }
    }

    private func personaInkColor(for persona: AgentSessionPersona) -> Color {
        switch persona {
        case .tars:
            return isDarkTheme ? Color(red: 0.63, green: 0.77, blue: 1.00) : Color(red: 0.12, green: 0.33, blue: 0.76)
        case .kipp:
            return isDarkTheme ? Color(red: 1.00, green: 0.88, blue: 0.44) : Color(red: 0.57, green: 0.42, blue: 0.02)
        case .case:
            return isDarkTheme ? Color(red: 0.56, green: 0.90, blue: 0.65) : Color(red: 0.10, green: 0.47, blue: 0.24)
        }
    }

    private func personaSoftFillColor(for persona: AgentSessionPersona) -> Color {
        personaColor(for: persona).opacity(isDarkTheme ? 0.26 : 0.18)
    }

    private func personaSoftStrokeColor(for persona: AgentSessionPersona) -> Color {
        personaColor(for: persona).opacity(isDarkTheme ? 0.34 : 0.22)
    }

    private func personaRoleLabel(for persona: AgentSessionPersona) -> String {
        switch persona {
        case .tars:
            return "implementer"
        case .kipp:
            return "optimizer"
        case .case:
            return "reviewer"
        }
    }

    private func personaFillColor(for persona: AgentSessionPersona) -> Color {
        if selectedSessionPersona == persona {
            return personaSoftFillColor(for: persona)
        }

        return .clear
    }

    private func personaStrokeColor(for persona: AgentSessionPersona) -> Color {
        if selectedSessionPersona == persona {
            return personaSoftStrokeColor(for: persona)
        }

        return .clear
    }

    private func personaTextColor(for persona: AgentSessionPersona) -> Color {
        if selectedSessionPersona == persona {
            return personaInkColor(for: persona)
        }

        return secondaryTextColor
    }

    private var selectedPersonaTag: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(personaSoftFillColor(for: selectedSessionPersona))
                .frame(width: 12, height: 12)

            Text(selectedSessionPersona.rawValue)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(personaInkColor(for: selectedSessionPersona))

            Text(personaRoleLabel(for: selectedSessionPersona))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(personaInkColor(for: selectedSessionPersona).opacity(isDarkTheme ? 0.90 : 0.80))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(mutedCardFillColor)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(personaColor(for: selectedSessionPersona).opacity(isDarkTheme ? 0.22 : 0.14), lineWidth: 1)
                )
        )
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
            resetAgentSession()
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
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    Text("Kubbo ")
                        .foregroundStyle(primaryTextColor)

                    Text("Agent")
                        .foregroundStyle(personaInkColor(for: selectedSessionPersona))
                }
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .frame(height: 36, alignment: .center)

                selectedPersonaTag

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
            HStack(spacing: 0) {
                ForEach(Array(AgentSessionPersona.allCases.enumerated()), id: \.element) { index, persona in
                    Button {
                        selectedSessionPersona = persona
                    } label: {
                        Text(persona.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(personaTextColor(for: persona))
                            .frame(minWidth: 46)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(personaFillColor(for: persona))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(personaStrokeColor(for: persona), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .agentCursorOnHover()

                    if index < AgentSessionPersona.allCases.count - 1 {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(width: 1, height: 16)
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(mutedCardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(cardStrokeColor, lineWidth: 1)
                    )
            )

            Circle()
                .fill(isResponding ? accentColor : Color(red: 0.23, green: 0.73, blue: 0.41))
                .frame(width: 8, height: 8)

            Text(isResponding ? "Thinking..." : "Conversation ready")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text("AI")
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
                    .fill(Color(red: 0.23, green: 0.73, blue: 0.41))
                    .frame(width: 8, height: 8)

                Text(smartTaskProviderLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryTextColor)
            }
            .help("Smart task generation is currently using \(smartTaskProviderLabel).")
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
                        terminalProviderStrip

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
                            AgentTypingIndicator(
                                label: activeCLIProvider.displayName,
                                secondaryTextColor: secondaryTextColor
                            )
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

    private var terminalProviderStrip: some View {
        HStack(spacing: 8) {
            Text("Provider")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(mutedCardFillColor)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 1)
                        )
                )

            Circle()
                .fill(Color(red: 0.23, green: 0.73, blue: 0.41))
                .frame(width: 8, height: 8)

            Text("\(smartTaskProviderLabel.capitalized) active")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private var promptComposer: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accentColor)

            TextField("Ask Kubbo Agent anything...", text: $draftPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
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

                    Text(isResponding ? "Thinking" : "Send")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
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

                Button(action: toggleIdeaComposer) {
                    AgentHeaderIcon(
                        symbol: "lightbulb",
                        isDarkTheme: isDarkTheme,
                        isActive: isIdeaComposerPresented,
                        accentColor: accentColor,
                        size: 32
                    )
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help(isIdeaComposerPresented ? "Close smart task composer" : "Open smart task composer")
            }
            .frame(height: 36)

            if isIdeaComposerPresented {
                smartTaskComposer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                taskPreviewInput
                    .transition(.move(edge: .top).combined(with: .opacity))

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
        .overlay(alignment: .bottom) {
            if pendingRemovedTask != nil {
                undoDeleteToast
                    .padding(.horizontal, 12)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isIdeaComposerPresented)
    }

    private var smartTaskComposer: some View {
        let ideaPromptInset: CGFloat = 18

        return VStack(alignment: .leading, spacing: 14) {
            Text("New Idea")
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

            HStack(alignment: .center, spacing: 12) {
                Text("Describe your idea")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)

                Spacer(minLength: 0)

                Button(action: closeIdeaComposer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help("Close smart task composer")
            }

            ZStack(alignment: .topLeading) {
                if !canGenerateIdeaCards {
                    Text("Ex: Prepare the launch plan for the new onboarding flow...")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor.opacity(0.58))
                        .padding(.top, ideaPromptInset)
                        .padding(.horizontal, ideaPromptInset)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $ideaPrompt)
                    .scrollContentBackground(.hidden)
                    .focused($isIdeaPromptFocused)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryTextColor)
                    .background(AgentIdeaPromptScrollViewConfigurator(text: ideaPrompt))
                    .padding(.horizontal, ideaPromptInset)
                    .padding(.vertical, ideaPromptInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isIdeaPromptFocused ? accentColor.opacity(0.68) : cardStrokeColor, lineWidth: 1)
                    )
            )

            Button(action: generateIdeaCards) {
                HStack(spacing: 10) {
                    if taskViewModel.isGeneratingIdeaTasks {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(taskViewModel.isGeneratingIdeaTasks ? "Generating..." : "Generate Smart Cards")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(
                    canGenerateIdeaCards && !taskViewModel.isGeneratingIdeaTasks
                        ? primaryTextColor
                        : secondaryTextColor.opacity(0.88)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            canGenerateIdeaCards && !taskViewModel.isGeneratingIdeaTasks
                                ? accentColor.opacity(isDarkTheme ? 0.92 : 0.82)
                                : accentColor.opacity(isDarkTheme ? 0.66 : 0.22)
                        )
                )
            }
            .buttonStyle(.plain)
            .agentCursorOnHover(isEnabled: canGenerateIdeaCards && !taskViewModel.isGeneratingIdeaTasks)
            .disabled(!canGenerateIdeaCards || taskViewModel.isGeneratingIdeaTasks)

            if let ideaGenerationErrorMessage = taskViewModel.ideaGenerationErrorMessage {
                Text(ideaGenerationErrorMessage)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.red.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private func closeWindow() {
        resetAgentSession()
        hostWindow?.close()
    }

    private func resetAgentSession() {
        cancelPendingResponse()
        cancelUndoDeleteTimer()
        draftPrompt = ""
        consoleEntries = AgentConsoleEntry.previewEntries
        cliOverride = nil
        cliSessionIdentifiers = [:]
        isIdeaComposerPresented = false
        ideaPrompt = ""
        editingTaskID = nil
        editingTaskTitle = ""
        pendingRemovedTask = nil
        isPromptFocused = false
        isIdeaPromptFocused = false
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

    private func toggleIdeaComposer() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isIdeaComposerPresented.toggle()
        }

        taskViewModel.clearIdeaGenerationError()

        if isIdeaComposerPresented {
            DispatchQueue.main.async {
                isIdeaPromptFocused = true
            }
        } else {
            isIdeaPromptFocused = false
        }
    }

    private func closeIdeaComposer() {
        withAnimation(.easeInOut(duration: 0.18)) {
            isIdeaComposerPresented = false
        }
        isIdeaPromptFocused = false
        taskViewModel.clearIdeaGenerationError()
    }

    private func generateIdeaCards() {
        guard canGenerateIdeaCards else { return }

        Task { @MainActor in
            let didGenerate = await taskViewModel.generateTasks(from: ideaPrompt)
            guard didGenerate else {
                return
            }

            ideaPrompt = ""
            closeIdeaComposer()
        }
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

    private func beginSidebarTaskEdition(_ task: TaskItem) {
        editingTaskID = task.id
        editingTaskTitle = task.title
    }

    private func saveSidebarTaskEdition(_ taskID: UUID) {
        taskViewModel.updateTaskTitle(taskID, title: editingTaskTitle)
        cancelSidebarTaskEdition()
    }

    private func cancelSidebarTaskEdition() {
        editingTaskID = nil
        editingTaskTitle = ""
    }

    private func deleteSidebarTask(_ taskID: UUID) {
        var removedTask: TaskViewModel.RemovedTask?
        withAnimation(.easeInOut(duration: 0.16)) {
            removedTask = taskViewModel.deleteTaskAndReturn(taskID)
            pendingRemovedTask = removedTask
        }

        guard removedTask != nil else {
            return
        }

        if editingTaskID == taskID {
            cancelSidebarTaskEdition()
        }

        scheduleUndoDeleteTimeout()
    }

    private func undoDeletedTask() {
        guard let pendingRemovedTask else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            taskViewModel.restoreTask(pendingRemovedTask.task, at: pendingRemovedTask.index)
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

    private func sidebarTaskRow(_ task: TaskItem) -> some View {
        let isEditing = editingTaskID == task.id

        return HStack(alignment: .top, spacing: 10) {
            Button {
                toggleSidebarTask(task.id)
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(task.isDone ? accentColor : secondaryTextColor.opacity(0.65))
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
                            saveSidebarTaskEdition(task.id)
                        }
                } else {
                    Text(task.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(task.isDone ? secondaryTextColor : primaryTextColor)
                        .strikethrough(task.isDone, color: secondaryTextColor.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                Button {
                    if isEditing {
                        saveSidebarTaskEdition(task.id)
                    } else {
                        beginSidebarTaskEdition(task)
                    }
                } label: {
                    AgentTaskRowActionIcon(
                        symbol: isEditing ? "checkmark" : "pencil",
                        isDarkTheme: isDarkTheme,
                        secondaryTextColor: secondaryTextColor
                    )
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help(isEditing ? "Save changes" : "Edit task")

                Button {
                    if isEditing {
                        cancelSidebarTaskEdition()
                    } else {
                        deleteSidebarTask(task.id)
                    }
                } label: {
                    AgentTaskRowActionIcon(
                        symbol: isEditing ? "xmark" : "trash",
                        isDarkTheme: isDarkTheme,
                        secondaryTextColor: secondaryTextColor
                    )
                }
                .buttonStyle(.plain)
                .agentCursorOnHover()
                .help(isEditing ? "Cancel editing" : "Delete task")
            }
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
        consoleEntries.append(.user(trimmedPrompt))

        if handleProviderCommand(trimmedPrompt) {
            isPromptFocused = true
            return
        }

        let provider = activeCLIProvider
        let sessionIdentifier = cliSessionIdentifiers[provider]

        responseTask?.cancel()
        isResponding = true
        responseTask = Task {
            do {
                let response = try await cliService.respond(
                    to: trimmedPrompt,
                    using: provider,
                    sessionIdentifier: sessionIdentifier
                )
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if let responseSessionIdentifier = response.sessionIdentifier {
                        cliSessionIdentifiers[provider] = responseSessionIdentifier
                    }
                    consoleEntries.append(.assistant(label: provider.displayName, text: response.text))
                    isResponding = false
                    responseTask = nil
                    isPromptFocused = true
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    consoleEntries.append(.status(error.localizedDescription))
                    isResponding = false
                    responseTask = nil
                    isPromptFocused = true
                }
            }
        }
    }

    private func handleProviderCommand(_ prompt: String) -> Bool {
        switch prompt.lowercased() {
        case "/codex":
            cliOverride = .codex
            consoleEntries.append(.status("Provider switched to Codex."))
            return true
        case "/gemini":
            cliOverride = .gemini
            consoleEntries.append(.status("Provider switched to Gemini."))
            return true
        case "/claude":
            consoleEntries.append(.status("Claude is not available in Kubbo Agent yet."))
            return true
        default:
            return false
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

private enum AgentCLIProvider: Hashable {
    case codex
    case gemini

    var displayName: String {
        switch self {
        case .codex:
            return "codex"
        case .gemini:
            return "gemini"
        }
    }
}

private enum AgentSessionPersona: String, CaseIterable, Hashable {
    case tars = "TARS"
    case kipp = "KIPP"
    case `case` = "CASE"
}

private enum AgentConsoleRoleStyle {
    case status
    case user
    case assistant
}

private struct AgentConsoleEntry: Identifiable {
    let id = UUID()
    let style: AgentConsoleRoleStyle
    let label: String
    let text: String

    static func status(_ text: String) -> Self {
        .init(style: .status, label: "info", text: text)
    }

    static func user(_ text: String) -> Self {
        .init(style: .user, label: "you", text: text)
    }

    static func assistant(label: String, text: String) -> Self {
        .init(style: .assistant, label: label, text: text)
    }

    static let previewEntries: [AgentConsoleEntry] = [
        .status("Session ready."),
        .assistant(label: "kubbo", text: "Ask for repository context, planning help, or a task breakdown. I will keep the task panel close while we work.")
    ]
}

private struct AgentConsoleRow: View {
    let entry: AgentConsoleEntry
    let accentColor: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color

    private var labelColor: Color {
        switch entry.style {
        case .status:
            return secondaryTextColor
        case .user:
            return accentColor
        case .assistant:
            return primaryTextColor
        }
    }

    private var messageColor: Color {
        entry.style == .status ? secondaryTextColor : primaryTextColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
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
    let label: String
    let secondaryTextColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 44, alignment: .leading)

            Text("thinking...")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
        }
    }
}

private enum AgentCLIServiceError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        }
    }
}

fileprivate final class AgentCLIService {
    private struct ResourceDescriptor {
        let path: String
        let bookmarkData: Data?
    }

    private struct HeadlessResponse: Decodable {
        struct ResponseError: Decodable {
            let message: String?
        }

        let response: String?
        let error: ResponseError?
    }

    fileprivate struct AgentCLIResponse {
        let text: String
        let sessionIdentifier: String?
    }

    private struct CodexSessionMetaEnvelope: Decodable {
        struct Payload: Decodable {
            let id: String
            let cwd: String?
        }

        let payload: Payload
    }

    private struct GeminiProjectRegistryData: Decodable {
        let projects: [String: String]
    }

    private struct GeminiConversationRecord: Decodable {
        let sessionId: String
    }

    private struct LaunchConfiguration {
        let executablePath: String
        let arguments: [String]
    }

    private let settingsRepository: SettingsRepository
    private let geminiAPIKeyStore: GeminiAPIKeyStoring
    private let codexExecutableResolver: CodexCLIExecutableResolving
    private let geminiExecutableResolver: GeminiCLIExecutableResolving
    private let nodeExecutableResolver: NodeRuntimeExecutableResolving
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(
        settingsRepository: SettingsRepository = UserDefaultsSettingsRepository(),
        geminiAPIKeyStore: GeminiAPIKeyStoring = KeychainGeminiAPIKeyStore(),
        codexExecutableResolver: CodexCLIExecutableResolving = DefaultCodexCLIExecutableResolver(),
        geminiExecutableResolver: GeminiCLIExecutableResolving = DefaultGeminiCLIExecutableResolver(),
        nodeExecutableResolver: NodeRuntimeExecutableResolving = DefaultNodeRuntimeExecutableResolver(),
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.settingsRepository = settingsRepository
        self.geminiAPIKeyStore = geminiAPIKeyStore
        self.codexExecutableResolver = codexExecutableResolver
        self.geminiExecutableResolver = geminiExecutableResolver
        self.nodeExecutableResolver = nodeExecutableResolver
        self.fileManager = fileManager
        self.decoder = decoder
    }

    func respond(
        to prompt: String,
        using provider: AgentCLIProvider,
        sessionIdentifier: String?
    ) async throws -> AgentCLIResponse {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AgentCLIServiceError.commandFailed("Type a message first.")
        }

        switch provider {
        case .codex:
            return try await runCodex(prompt: trimmedPrompt, sessionIdentifier: sessionIdentifier)
        case .gemini:
            return try await runGemini(prompt: trimmedPrompt, sessionIdentifier: sessionIdentifier)
        }
    }

    private func runCodex(prompt: String, sessionIdentifier: String?) async throws -> AgentCLIResponse {
        guard canUseLocalCLI else {
            throw AgentCLIServiceError.commandFailed(
                "This sandboxed build cannot launch Codex CLI. Run the Debug build from Xcode to use your local Codex session."
            )
        }

        let snapshot = settingsRepository.load()
        let executableDescriptor = try resolvedCodexExecutableDescriptor(snapshot: snapshot)
        let nodeExecutableDescriptor = try resolvedNodeExecutableDescriptor(
            for: executableDescriptor,
            snapshot: snapshot
        )
        let workingDirectoryDescriptor = workingDirectoryDescriptor(snapshot: snapshot)
        let workingDirectoryURL = workingDirectoryURL(from: workingDirectoryDescriptor)
        let outputURL = fileManager.temporaryDirectory
            .appendingPathComponent("agent-codex-\(UUID().uuidString.lowercased()).txt")
        let startedAt = Date()

        defer {
            try? fileManager.removeItem(at: outputURL)
        }

        let launchConfiguration = try launchConfiguration(
            for: executableDescriptor,
            nodeExecutableDescriptor: nodeExecutableDescriptor,
            arguments: codexArguments(
                prompt: prompt,
                model: normalizedCodexModelIdentifier(snapshot: snapshot),
                outputURL: outputURL,
                sessionIdentifier: sessionIdentifier
            )
        )

        let result = try await withSecurityScopedAccess(
            descriptors: [executableDescriptor, nodeExecutableDescriptor, workingDirectoryDescriptor].compactMap { $0 }
        ) {
            try await runProcess(
                executablePath: launchConfiguration.executablePath,
                arguments: launchConfiguration.arguments,
                currentDirectoryURL: workingDirectoryURL,
                environment: codexExecutionEnvironment()
            )
        }

        guard result.exitCode == 0 else {
            throw AgentCLIServiceError.commandFailed(
                normalizedCodexCLIError(stderr: result.stderr, stdout: result.stdout)
            )
        }

        let responseText = (try? String(contentsOf: outputURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        let fallbackOutput = normalizedCommandOutput(stderr: result.stderr, stdout: result.stdout)
        let outputText = !responseText.isEmpty ? responseText : fallbackOutput

        guard !outputText.isEmpty else {
            throw AgentCLIServiceError.commandFailed("Codex CLI returned an empty response.")
        }

        let resolvedSessionIdentifier = sessionIdentifier ??
            discoverLatestCodexSessionIdentifier(
                since: startedAt,
                workingDirectoryPath: normalizeProjectPath(
                    workingDirectoryURL?.path ?? fileManager.homeDirectoryForCurrentUser.path
                )
            )

        return AgentCLIResponse(text: outputText, sessionIdentifier: resolvedSessionIdentifier)
    }

    private func runGemini(prompt: String, sessionIdentifier: String?) async throws -> AgentCLIResponse {
        guard canUseLocalCLI else {
            throw AgentCLIServiceError.commandFailed(
                "This sandboxed build cannot launch Gemini CLI. Run the Debug build from Xcode to use your local Gemini session."
            )
        }

        let snapshot = settingsRepository.load()
        let executableDescriptor = try resolvedGeminiExecutableDescriptor(snapshot: snapshot)
        let nodeExecutableDescriptor = try resolvedNodeExecutableDescriptor(
            for: executableDescriptor,
            snapshot: snapshot
        )
        let workingDirectoryDescriptor = workingDirectoryDescriptor(snapshot: snapshot)
        let workingDirectoryURL = workingDirectoryURL(from: workingDirectoryDescriptor)
        let startedAt = Date()
        let geminiHomePath = geminiCLIHomePath()

        let launchConfiguration = try launchConfiguration(
            for: executableDescriptor,
            nodeExecutableDescriptor: nodeExecutableDescriptor,
            arguments: geminiArguments(
                prompt: prompt,
                model: normalizedGeminiModelIdentifier(snapshot: snapshot),
                sessionIdentifier: sessionIdentifier
            )
        )

        let result = try await withSecurityScopedAccess(
            descriptors: [executableDescriptor, nodeExecutableDescriptor, workingDirectoryDescriptor].compactMap { $0 }
        ) {
            try await runProcess(
                executablePath: launchConfiguration.executablePath,
                arguments: launchConfiguration.arguments,
                currentDirectoryURL: workingDirectoryURL,
                environment: geminiExecutionEnvironment()
            )
        }

        guard result.exitCode == 0 else {
            throw AgentCLIServiceError.commandFailed(
                normalizedGeminiCLIError(stderr: result.stderr, stdout: result.stdout)
            )
        }

        guard let responseData = result.stdout.data(using: .utf8) else {
            throw AgentCLIServiceError.commandFailed("Gemini CLI returned an invalid response.")
        }

        let payload: HeadlessResponse
        do {
            payload = try decoder.decode(HeadlessResponse.self, from: responseData)
        } catch {
            throw AgentCLIServiceError.commandFailed("Gemini CLI returned an invalid response.")
        }

        if let errorMessage = payload.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !errorMessage.isEmpty {
            throw AgentCLIServiceError.commandFailed(errorMessage)
        }

        let outputText = payload.response?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !outputText.isEmpty else {
            throw AgentCLIServiceError.commandFailed("Gemini CLI returned an empty response.")
        }

        let resolvedSessionIdentifier = sessionIdentifier ??
            discoverLatestGeminiSessionIdentifier(
                since: startedAt,
                projectRootPath: normalizeProjectPath(
                    workingDirectoryURL?.path ?? fileManager.homeDirectoryForCurrentUser.path
                ),
                geminiCLIHomePath: geminiHomePath
            )

        return AgentCLIResponse(text: outputText, sessionIdentifier: resolvedSessionIdentifier)
    }

    private var canUseLocalCLI: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
    }

    private func resolvedCodexExecutableDescriptor(snapshot: SettingsSnapshot) throws -> ResourceDescriptor {
        if let manualPath = snapshot.codexExecutablePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !manualPath.isEmpty {
            return ResourceDescriptor(path: manualPath, bookmarkData: snapshot.codexExecutableBookmarkData)
        }

        guard let detectedPath = codexExecutableResolver.resolveExecutablePath() else {
            throw AgentCLIServiceError.commandFailed("Codex CLI was not found. Install `codex` first.")
        }

        return ResourceDescriptor(path: detectedPath, bookmarkData: nil)
    }

    private func resolvedGeminiExecutableDescriptor(snapshot: SettingsSnapshot) throws -> ResourceDescriptor {
        if let manualPath = snapshot.geminiExecutablePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !manualPath.isEmpty {
            return ResourceDescriptor(path: manualPath, bookmarkData: snapshot.geminiExecutableBookmarkData)
        }

        guard let detectedPath = geminiExecutableResolver.resolveExecutablePath() else {
            throw AgentCLIServiceError.commandFailed("Gemini CLI was not found. Install `gemini` first.")
        }

        return ResourceDescriptor(path: detectedPath, bookmarkData: nil)
    }

    private func resolvedNodeExecutableDescriptor(
        for executableDescriptor: ResourceDescriptor,
        snapshot: SettingsSnapshot
    ) throws -> ResourceDescriptor? {
        guard requiresNodeRuntime(for: executableDescriptor) else {
            return nil
        }

        if let manualPath = snapshot.nodeExecutablePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !manualPath.isEmpty {
            return ResourceDescriptor(path: manualPath, bookmarkData: snapshot.nodeExecutableBookmarkData)
        }

        guard let detectedPath = nodeExecutableResolver.resolveNodeExecutablePath() else {
            throw AgentCLIServiceError.commandFailed(
                "Node.js runtime was not found. In Settings > API Keys, choose `/usr/local/bin/node`."
            )
        }

        return ResourceDescriptor(path: detectedPath, bookmarkData: nil)
    }

    private func workingDirectoryDescriptor(snapshot: SettingsSnapshot) -> ResourceDescriptor? {
        if let rootPath = snapshot.localRepositoriesRootPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rootPath.isEmpty {
            return ResourceDescriptor(path: rootPath, bookmarkData: snapshot.localRepositoriesRootBookmarkData)
        }

        return nil
    }

    private func workingDirectoryURL(from descriptor: ResourceDescriptor?) -> URL? {
        if let descriptor {
            return URL(fileURLWithPath: descriptor.path, isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
    }

    private func launchConfiguration(
        for executableDescriptor: ResourceDescriptor,
        nodeExecutableDescriptor: ResourceDescriptor?,
        arguments: [String]
    ) throws -> LaunchConfiguration {
        let executablePath = preferredLaunchPath(for: executableDescriptor)

        if let nodeExecutableDescriptor {
            return LaunchConfiguration(
                executablePath: preferredLaunchPath(for: nodeExecutableDescriptor),
                arguments: [executablePath] + arguments
            )
        }

        return LaunchConfiguration(executablePath: executablePath, arguments: arguments)
    }

    private func codexArguments(
        prompt: String,
        model: String?,
        outputURL: URL,
        sessionIdentifier: String?
    ) -> [String] {
        var arguments = ["exec"]

        if sessionIdentifier != nil {
            arguments.append("resume")
        }

        arguments.append(contentsOf: [
            "--skip-git-repo-check",
            "--output-last-message",
            outputURL.path
        ])

        if sessionIdentifier == nil {
            arguments.append(contentsOf: [
                "--sandbox",
                "read-only",
                "--color",
                "never"
            ])
        }

        if let model {
            arguments.append(contentsOf: ["--model", model])
        }

        if let sessionIdentifier {
            arguments.append(sessionIdentifier)
        }

        arguments.append(prompt)
        return arguments
    }

    private func geminiArguments(prompt: String, model: String?, sessionIdentifier: String?) -> [String] {
        var arguments: [String] = []

        if let sessionIdentifier {
            arguments.append(contentsOf: ["--resume", sessionIdentifier])
        }

        arguments.append(contentsOf: [
            "-p",
            prompt,
            "--output-format",
            "json"
        ])

        if let model {
            arguments.append(contentsOf: ["--model", model])
        }

        return arguments
    }

    private func codexExecutionEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = effectiveExecutionPATH
        return environment
    }

    private func geminiExecutionEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = effectiveExecutionPATH

        let normalizedAPIKey = geminiAPIKeyStore.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedAPIKey.isEmpty {
            environment["GEMINI_API_KEY"] = normalizedAPIKey
        }

        return environment
    }

    private var effectiveExecutionPATH: String {
        let fallbackPath = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        if let inheritedPath = ProcessInfo.processInfo.environment["PATH"],
           !inheritedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(fallbackPath):\(inheritedPath)"
        }

        return fallbackPath
    }

    private func normalizedCodexModelIdentifier(snapshot: SettingsSnapshot) -> String? {
        let rawValue = snapshot.selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else {
            return nil
        }

        switch rawValue {
        case "Gemini 1.5 Pro", "Claude 3.7 Sonnet":
            return nil
        default:
            return rawValue
        }
    }

    private func normalizedGeminiModelIdentifier(snapshot: SettingsSnapshot) -> String? {
        let rawValue = snapshot.geminiSelectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return rawValue.isEmpty ? nil : rawValue
    }

    private func preferredLaunchPath(for descriptor: ResourceDescriptor) -> String {
        guard descriptor.bookmarkData == nil else {
            return descriptor.path
        }

        let resolvedPath = URL(fileURLWithPath: descriptor.path).resolvingSymlinksInPath().path
        return resolvedPath.isEmpty ? descriptor.path : resolvedPath
    }

    private func requiresNodeRuntime(for descriptor: ResourceDescriptor) -> Bool {
        let launchPath = preferredLaunchPath(for: descriptor)
        if launchPath.lowercased().hasSuffix(".js") {
            return true
        }

        guard fileManager.fileExists(atPath: launchPath),
              let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: launchPath)) else {
            return false
        }
        defer {
            try? handle.close()
        }

        guard let data = try? handle.read(upToCount: 160),
              let shebang = String(data: data, encoding: .utf8)?
                .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) else {
            return false
        }

        return shebang.hasPrefix("#!") && shebang.contains("node")
    }

    private func normalizedCommandOutput(stderr: String, stdout: String) -> String {
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedError.isEmpty {
            return trimmedError
        }

        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedCodexCLIError(stderr: String, stdout: String) -> String {
        let message = normalizedCommandOutput(stderr: stderr, stdout: stdout)
        let normalizedMessage = message.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if normalizedMessage.contains("login required") ||
            normalizedMessage.contains("please login") ||
            normalizedMessage.contains("please log in") ||
            normalizedMessage.contains("not logged in") ||
            normalizedMessage.contains("not authenticated") ||
            normalizedMessage.contains("auth") {
            return "Codex CLI is installed, but your local session is not authenticated. In Terminal, run `codex login` and choose ChatGPT."
        }

        return message.isEmpty ? "Codex CLI failed." : message
    }

    private func normalizedGeminiCLIError(stderr: String, stdout: String) -> String {
        let message = normalizedCommandOutput(stderr: stderr, stdout: stdout)
        let normalizedMessage = message.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if normalizedMessage.contains("login") ||
            normalizedMessage.contains("log in") ||
            normalizedMessage.contains("sign in") ||
            normalizedMessage.contains("not authenticated") ||
            normalizedMessage.contains("authentication") ||
            normalizedMessage.contains("credentials") ||
            normalizedMessage.contains("api key") {
            return "Gemini CLI is installed, but your local session is not authenticated. In Terminal, run `gemini` and choose Sign in with Google, or save a Gemini API key in Settings > API Keys."
        }

        return message.isEmpty ? "Gemini CLI failed." : message
    }

    private func codexSessionsRootURL() -> URL {
        if let codexHomePath = ProcessInfo.processInfo.environment["CODEX_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !codexHomePath.isEmpty {
            return URL(fileURLWithPath: codexHomePath, isDirectory: true)
                .appendingPathComponent("sessions", isDirectory: true)
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
    }

    private func codexSessionMeta(at fileURL: URL) -> CodexSessionMetaEnvelope? {
        guard let fileContents = try? String(contentsOf: fileURL, encoding: .utf8),
              let firstLine = fileContents.split(separator: "\n", maxSplits: 1).first
        else {
            return nil
        }

        return try? decoder.decode(CodexSessionMetaEnvelope.self, from: Data(firstLine.utf8))
    }

    private func discoverLatestCodexSessionIdentifier(since: Date, workingDirectoryPath: String) -> String? {
        let sessionsRootURL = codexSessionsRootURL()
        guard let enumerator = fileManager.enumerator(
            at: sessionsRootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let lowerBound = since.addingTimeInterval(-2)
        var candidateFiles: [(url: URL, modifiedAt: Date)] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl",
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else {
                continue
            }

            let modifiedAt = resourceValues.contentModificationDate ?? .distantPast
            guard modifiedAt >= lowerBound else {
                continue
            }

            candidateFiles.append((fileURL, modifiedAt))
        }

        for candidate in candidateFiles.sorted(by: { $0.modifiedAt > $1.modifiedAt }) {
            guard let sessionMeta = codexSessionMeta(at: candidate.url),
                  let sessionWorkingDirectory = normalizeProjectPath(sessionMeta.payload.cwd),
                  sessionWorkingDirectory == workingDirectoryPath
            else {
                continue
            }

            return sessionMeta.payload.id
        }

        return nil
    }

    private func geminiCLIHomePath() -> String {
        if let geminiHomePath = ProcessInfo.processInfo.environment["GEMINI_CLI_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !geminiHomePath.isEmpty {
            return geminiHomePath
        }

        return fileManager.homeDirectoryForCurrentUser.path
    }

    private func geminiProjectIdentifier(
        for projectRootPath: String,
        geminiCLIHomePath: String
    ) -> String? {
        let registryURL = URL(fileURLWithPath: geminiCLIHomePath, isDirectory: true)
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("projects.json")

        guard let registryData = try? Data(contentsOf: registryURL),
              let registry = try? decoder.decode(GeminiProjectRegistryData.self, from: registryData)
        else {
            return nil
        }

        return registry.projects.first {
            normalizeProjectPath($0.key) == projectRootPath
        }?.value
    }

    private func discoverLatestGeminiSessionIdentifier(
        since: Date,
        projectRootPath: String,
        geminiCLIHomePath: String
    ) -> String? {
        guard let projectIdentifier = geminiProjectIdentifier(
            for: projectRootPath,
            geminiCLIHomePath: geminiCLIHomePath
        ) else {
            return nil
        }

        let chatsDirectoryURL = URL(fileURLWithPath: geminiCLIHomePath, isDirectory: true)
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
            .appendingPathComponent(projectIdentifier, isDirectory: true)
            .appendingPathComponent("chats", isDirectory: true)

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: chatsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let lowerBound = since.addingTimeInterval(-2)
        let candidateFiles = fileURLs.compactMap { fileURL -> (url: URL, modifiedAt: Date)? in
            guard fileURL.pathExtension == "json",
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true
            else {
                return nil
            }

            let modifiedAt = resourceValues.contentModificationDate ?? .distantPast
            guard modifiedAt >= lowerBound else {
                return nil
            }

            return (fileURL, modifiedAt)
        }

        for candidate in candidateFiles.sorted(by: { $0.modifiedAt > $1.modifiedAt }) {
            guard let data = try? Data(contentsOf: candidate.url),
                  let conversationRecord = try? decoder.decode(GeminiConversationRecord.self, from: data),
                  !conversationRecord.sessionId.isEmpty
            else {
                continue
            }

            return conversationRecord.sessionId
        }

        return nil
    }

    private func normalizeProjectPath(_ path: String?) -> String? {
        guard let path else {
            return nil
        }

        return normalizeProjectPath(path)
    }

    private func normalizeProjectPath(_ path: String) -> String {
        var normalizedPath = URL(fileURLWithPath: path, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        while normalizedPath.count > 1 && normalizedPath.hasSuffix("/") {
            normalizedPath.removeLast()
        }

        return normalizedPath
    }

    private func withSecurityScopedAccess<T>(
        descriptors: [ResourceDescriptor],
        operation: () async throws -> T
    ) async throws -> T {
        let bookmarkPayloads = descriptors.compactMap(\.bookmarkData)
        guard !bookmarkPayloads.isEmpty else {
            return try await operation()
        }

        var scopedURLs: [URL] = []
        for bookmarkData in bookmarkPayloads {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if url.startAccessingSecurityScopedResource() {
                scopedURLs.append(url)
            }
        }

        defer {
            for url in scopedURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try await operation()
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        currentDirectoryURL: URL?,
        environment: [String: String]
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdinPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = stdinPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                try? stdinPipe.fileHandleForWriting.close()
                continuation.resume(
                    throwing: AgentCLIServiceError.commandFailed(
                        error.localizedDescription.isEmpty
                            ? "Failed to execute CLI."
                            : error.localizedDescription
                    )
                )
            }
        }
    }
}

private struct AgentTaskRowActionIcon: View {
    let symbol: String
    let isDarkTheme: Bool
    let secondaryTextColor: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(secondaryTextColor)
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDarkTheme ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isDarkTheme ? Color.white.opacity(0.14) : Color.black.opacity(0.10), lineWidth: 1)
                    )
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

private struct AgentIdeaPromptScrollViewConfigurator: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let scrollView = findTextEditorScrollView(from: nsView) else {
                return
            }

            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
            scrollView.scrollerStyle = .overlay

            guard let textView = scrollView.documentView as? NSTextView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else {
                scrollView.hasVerticalScroller = false
                return
            }

            textView.textContainerInset = .zero
            textContainer.lineFragmentPadding = 0
            layoutManager.ensureLayout(for: textContainer)

            let usedHeight = layoutManager.usedRect(for: textContainer).height + (textView.textContainerInset.height * 2)
            let visibleHeight = scrollView.contentSize.height
            let shouldShowScroller = !text.isEmpty && usedHeight > visibleHeight + 1

            scrollView.hasVerticalScroller = shouldShowScroller
        }
    }

    private func findTextEditorScrollView(from view: NSView) -> NSScrollView? {
        var currentView: NSView? = view

        while let unwrappedCurrentView = currentView {
            if let match = findTextEditorScrollView(in: unwrappedCurrentView) {
                return match
            }
            currentView = unwrappedCurrentView.superview
        }

        return nil
    }

    private func findTextEditorScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView,
           scrollView.documentView is NSTextView {
            return scrollView
        }

        for subview in view.subviews {
            if let match = findTextEditorScrollView(in: subview) {
                return match
            }
        }

        return nil
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
