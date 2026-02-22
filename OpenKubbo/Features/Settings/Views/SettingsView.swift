import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var hostWindow: NSWindow?
    @State private var isGitHubClientIDVisible = false

    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    private let panelWidth: CGFloat = 760
    private let panelHeight: CGFloat = 640
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    private var accentPalette: [Color] {
        [
            Color(red: 0.39, green: 0.44, blue: 0.99),
            Color(red: 0.30, green: 0.53, blue: 0.98),
            Color(red: 0.55, green: 0.35, blue: 0.88),
            Color(red: 0.83, green: 0.30, blue: 0.62),
            Color(red: 0.88, green: 0.29, blue: 0.33),
            Color(red: 0.90, green: 0.47, blue: 0.19),
            Color(red: 0.23, green: 0.73, blue: 0.41)
        ]
    }

    private var isDarkTheme: Bool {
        themeStore.resolvedColorScheme(systemColorScheme: systemColorScheme) == .dark
    }

    private var panelFillColor: Color {
        isDarkTheme ? Color(red: 0.12, green: 0.13, blue: 0.16) : .white
    }

    private var panelStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.08)
    }

    private var cardFillColor: Color {
        isDarkTheme ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white
    }

    private var cardStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.90) : .black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.62) : .black.opacity(0.52)
    }

    private var tertiaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.48) : .black.opacity(0.44)
    }

    private var dividerColor: Color {
        isDarkTheme ? .white.opacity(0.12) : .black.opacity(0.08)
    }

    private var searchPlaceholderColor: Color {
        isDarkTheme ? .white.opacity(0.44) : .black.opacity(0.42)
    }

    private var selectedTabFillColor: Color {
        Color(red: 0.39, green: 0.41, blue: 0.93).opacity(isDarkTheme ? 0.34 : 0.20)
    }

    private var selectedTabStrokeColor: Color {
        Color(red: 0.39, green: 0.41, blue: 0.93).opacity(0.45)
    }

    private var githubSectionFillColor: Color {
        isDarkTheme ? Color.white.opacity(0.03) : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var githubSectionStrokeColor: Color {
        isDarkTheme ? Color.white.opacity(0.12) : Color.black.opacity(0.11)
    }

    private var githubInputFillColor: Color {
        isDarkTheme ? Color(red: 0.12, green: 0.14, blue: 0.18) : .white
    }

    private var githubInputStrokeColor: Color {
        isDarkTheme ? Color.white.opacity(0.16) : Color.black.opacity(0.12)
    }

    private var githubPrimaryButtonTint: Color {
        isDarkTheme
        ? Color(red: 0.34, green: 0.72, blue: 0.31)
        : Color(red: 0.19, green: 0.53, blue: 0.88)
    }

    private var githubSecondaryButtonFillColor: Color {
        isDarkTheme
        ? Color(red: 0.26, green: 0.28, blue: 0.34)
        : Color(red: 0.86, green: 0.90, blue: 0.96)
    }

    private var githubSecondaryButtonTextColor: Color {
        isDarkTheme
        ? Color.white.opacity(0.90)
        : Color(red: 0.15, green: 0.24, blue: 0.37)
    }

    private var githubSecondaryButtonStrokeColor: Color {
        isDarkTheme
        ? Color.white.opacity(0.16)
        : Color(red: 0.69, green: 0.75, blue: 0.84)
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
                settingsWorkspace
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
                )
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
            }
        )
    }

    private var settingsWorkspace: some View {
        HStack(alignment: .top, spacing: 14) {
            sidebar

            Rectangle()
                .fill(dividerColor)
                .frame(width: 1)
                .padding(.vertical, 8)

            contentScroll
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("Config")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .frame(height: 36, alignment: .center)

                Spacer()
            }
            .frame(height: 36)
            .background(SettingsWindowDragRegion())

            HStack(spacing: 8) {
                Button(action: closeSettingsWindow) {
                    SettingsHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tertiaryTextColor)
                .frame(width: 20)

            TextField(
                "",
                text: $viewModel.searchText,
                prompt: Text("Buscar ajustes...").foregroundColor(searchPlaceholderColor)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(primaryTextColor)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(tertiaryTextColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1.2)
                )
        )
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchRow
            sidebarTabs
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private var sidebarTabs: some View {
        Group {
            if viewModel.visibleTabs.isEmpty {
                EmptySettingsStateView(isDarkTheme: isDarkTheme)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.visibleTabs) { tab in
                        sidebarTabButton(tab)
                    }
                }
            }
        }
    }

    private func sidebarTabButton(_ tab: SettingsTab) -> some View {
        Button {
            viewModel.selectTab(tab)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(viewModel.activeTab == tab ? primaryTextColor : secondaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(viewModel.activeTab == tab ? selectedTabFillColor : cardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(viewModel.activeTab == tab ? selectedTabStrokeColor : cardStrokeColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch viewModel.activeTab {
                case .general:
                    generalContent
                case .appearance:
                    appearanceContent
                case .codexCLI:
                    codexContent
                case .github:
                    githubContent
                case .shortcuts:
                    shortcutsContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack {
                Text("Configuração ativa")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer()

                Text(viewModel.activeTab.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("GENERAL")
            settingsCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Under Construction")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Text("General settings are under construction.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var appearanceContent: some View {
        let selectedTheme = viewModel.selectedThemeMode

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TEMA")
            HStack(spacing: 10) {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        viewModel.selectedThemeMode = mode
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(themePreviewBackground(for: mode))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(mode == selectedTheme ? Color(red: 0.44, green: 0.45, blue: 0.98) : cardStrokeColor.opacity(0.85), lineWidth: mode == selectedTheme ? 2 : 1)
                                )
                                .frame(height: 76)
                                .overlay(themePreviewContent(for: mode))

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            sectionTitle("COR DE DESTAQUE")
            HStack(spacing: 10) {
                ForEach(accentPalette.indices, id: \.self) { index in
                    Button {
                        viewModel.selectedAccentColorIndex = index
                    } label: {
                        Circle()
                            .fill(accentPalette[index])
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke((isDarkTheme ? Color.white.opacity(0.86) : Color.black.opacity(0.82)).opacity(index == viewModel.selectedAccentColorIndex ? 1 : 0), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var codexContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CODEX CLI")
            settingsCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Under Construction")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Text("Codex CLI settings are under construction.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SHORTCUTS")
            settingsCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Under Construction")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Text("Shortcuts are under construction.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var githubContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("GITHUB")
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect your GitHub account")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Text("Use a GitHub OAuth App Client ID to sign in with Device Flow.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    githubClientIDInput

                    githubSectionCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How to connect")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)

                            Text("1. Click Login with GitHub.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryTextColor)

                            Text("2. Click Open GitHub Device Page.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryTextColor)

                            Text("3. Enter the code shown below and authorize.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }

                    githubSectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device URL")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)

                            Text(gitHubDeviceURLString)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(primaryTextColor)
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(githubInputFillColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(githubInputStrokeColor, lineWidth: 1)
                                        )
                                )

                            HStack(spacing: 10) {
                                githubSecondaryButton("Open Device URL") {
                                    openGitHubDevicePage()
                                }

                                githubSecondaryButton("Copy Device URL") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(gitHubDeviceURLString, forType: .string)
                                }
                            }
                        }
                    }

                    if viewModel.isGitHubConnected {
                        githubSectionCard {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Connected")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(secondaryTextColor)
                                    Text(viewModel.githubDisplayName)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(primaryTextColor)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 8) {
                                    githubSecondaryButton("Disconnect") {
                                        viewModel.logoutGitHub()
                                    }

                                    githubSecondaryButton("Open GitHub Device Page") {
                                        openGitHubDevicePage()
                                    }
                                }
                            }
                        }

                        githubSectionCard {
                            githubRepositoriesSection
                        }

                        githubSectionCard {
                            githubIssueSection
                        }

                        githubSectionCard {
                            githubPullRequestSection
                        }

                        githubSectionCard {
                            githubCommitSection
                        }
                    } else {
                        githubSectionCard {
                            Button {
                                Task {
                                    await viewModel.loginWithGitHub()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if viewModel.isGitHubAuthenticating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(viewModel.isGitHubAuthenticating ? "Authorizing..." : "Login with GitHub")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(githubPrimaryButtonTint)
                            .disabled(
                                viewModel.isGitHubAuthenticating ||
                                viewModel.githubClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )

                            if viewModel.githubClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Paste your GitHub OAuth App Client ID to enable login.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(tertiaryTextColor)
                            }

                            githubSecondaryButton("Open GitHub Device Page") {
                                openGitHubDevicePage()
                            }
                        }
                    }

                    if let userCode = viewModel.githubUserCode {
                        githubSectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("Code:")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(secondaryTextColor)

                                    Text(userCode)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(primaryTextColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(githubInputFillColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .stroke(githubInputStrokeColor, lineWidth: 1)
                                                )
                                        )
                                }

                                githubSecondaryButton("Copy Code") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(userCode, forType: .string)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.githubStatusMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(secondaryTextColor)

                        if let githubErrorMessage = viewModel.githubErrorMessage {
                            Text(githubErrorMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(0.85))
                        }

                        if let githubActionStatusMessage = viewModel.githubActionStatusMessage {
                            Text(githubActionStatusMessage)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        }

                        if let githubActionErrorMessage = viewModel.githubActionErrorMessage {
                            Text(githubActionErrorMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(0.85))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private func githubSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(githubSectionFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(githubSectionStrokeColor, lineWidth: 1)
                )
        )
    }

    private func githubSecondaryButton(
        _ title: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(githubSecondaryButtonTextColor.opacity(isDisabled ? 0.65 : 1))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(githubSecondaryButtonFillColor.opacity(isDisabled ? (isDarkTheme ? 0.65 : 0.72) : 1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(githubSecondaryButtonStrokeColor.opacity(isDisabled ? 0.6 : 1), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var githubRepositoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repositories")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            HStack(spacing: 10) {
                githubSecondaryButton("Load Repositories", isDisabled: viewModel.isGitHubLoadingRepositories) {
                    Task {
                        await viewModel.loadGitHubRepositories()
                    }
                }

                if viewModel.isGitHubLoadingRepositories {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            TextField("Target repository (owner/repo)", text: $viewModel.githubTargetRepository)
                .textFieldStyle(.roundedBorder)

            if !viewModel.githubRepositorySuggestions.isEmpty {
                Menu {
                    ForEach(viewModel.githubRepositorySuggestions, id: \.self) { repository in
                        Button(repository) {
                            viewModel.githubTargetRepository = repository
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Use loaded repository")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(githubSecondaryButtonTextColor)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(githubSecondaryButtonFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(githubSecondaryButtonStrokeColor, lineWidth: 1)
                            )
                    )
                }
                .menuStyle(.borderlessButton)

                Text("Loaded \(viewModel.githubRepositorySuggestions.count) repositories.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryTextColor)
            }
        }
    }

    private var githubIssueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Issue")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            TextField("Issue title", text: $viewModel.githubIssueTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Issue body (optional)", text: $viewModel.githubIssueBody)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await viewModel.createGitHubIssue()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isGitHubCreatingIssue {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isGitHubCreatingIssue ? "Creating Issue..." : "Create Issue")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(githubPrimaryButtonTint)
            .disabled(viewModel.isGitHubCreatingIssue || viewModel.githubTargetRepository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var githubPullRequestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Pull Request")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            TextField("Pull request title", text: $viewModel.githubPRTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Head branch (ex: feature/my-branch)", text: $viewModel.githubPRHead)
                .textFieldStyle(.roundedBorder)

            TextField("Base branch (ex: main)", text: $viewModel.githubPRBase)
                .textFieldStyle(.roundedBorder)

            TextField("Pull request body (optional)", text: $viewModel.githubPRBody)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await viewModel.createGitHubPullRequest()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isGitHubCreatingPR {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isGitHubCreatingPR ? "Creating PR..." : "Create Pull Request")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(githubPrimaryButtonTint)
            .disabled(viewModel.isGitHubCreatingPR || viewModel.githubTargetRepository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var githubCommitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Commit File")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            TextField("File path (ex: docs/notes.md)", text: $viewModel.githubCommitPath)
                .textFieldStyle(.roundedBorder)

            TextField("Commit message", text: $viewModel.githubCommitMessage)
                .textFieldStyle(.roundedBorder)

            TextField("Branch (ex: main)", text: $viewModel.githubCommitBranch)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $viewModel.githubCommitContent)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minHeight: 100, maxHeight: 100)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(cardFillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 1)
                        )
                )

            Button {
                Task {
                    await viewModel.commitGitHubFile()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isGitHubCommittingFile {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isGitHubCommittingFile ? "Committing..." : "Commit File")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(githubPrimaryButtonTint)
            .disabled(viewModel.isGitHubCommittingFile || viewModel.githubTargetRepository.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func openGitHubDevicePage() {
        if let verificationURL = viewModel.githubVerificationURL ?? URL(string: gitHubDeviceURLString) {
            NSWorkspace.shared.open(verificationURL)
        }
    }

    private var githubClientIDInput: some View {
        HStack(spacing: 8) {
            Group {
                if isGitHubClientIDVisible {
                    TextField("GitHub OAuth App Client ID", text: $viewModel.githubClientID)
                } else {
                    SecureField("GitHub OAuth App Client ID", text: $viewModel.githubClientID)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(primaryTextColor)

            Button {
                isGitHubClientIDVisible.toggle()
            } label: {
                Image(systemName: isGitHubClientIDVisible ? "eye" : "eye.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(isGitHubClientIDVisible ? "Client ID is visible. Click to hide." : "Client ID is hidden. Click to show.")
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(githubInputFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(githubInputStrokeColor, lineWidth: 1)
                )
        )
    }

    private var gitHubDeviceURLString: String {
        "https://github.com/login/device"
    }

    private func rowValue(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(secondaryTextColor)
            .tracking(0.7)
            .padding(.top, 2)
    }

    private func toggleRow(icon: String? = nil, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 20)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(red: 0.39, green: 0.44, blue: 0.99))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private func themePreviewBackground(for mode: ThemeMode) -> AnyShapeStyle {
        switch mode {
        case .light:
            return AnyShapeStyle(Color.white.opacity(0.90))
        case .dark:
            return AnyShapeStyle(Color.black.opacity(0.76))
        case .automatic:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(0.84), .black.opacity(0.80)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    @ViewBuilder
    private func themePreviewContent(for mode: ThemeMode) -> some View {
        switch mode {
        case .light:
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.black.opacity(0.10))
                    .frame(width: 92, height: 12)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.black.opacity(0.08))
                    .frame(width: 70, height: 8)
            }
        case .dark:
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .frame(width: 92, height: 12)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .frame(width: 70, height: 8)
            }
        case .automatic:
            Text("Auto")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.78))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(.white)
                        .overlay(
                            Capsule()
                                .stroke(.black.opacity(0.20), lineWidth: 1)
                        )
                )
        }
    }

    private func closeSettingsWindow() {
        hostWindow?.close()
    }
}
