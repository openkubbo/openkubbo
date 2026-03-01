import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var hostWindow: NSWindow?
    @State private var isWindowPinned = true
    @State private var isGitHubClientIDVisible = false
    @State private var localRepositoriesRootErrorMessage: String?

    private let isAppUpdateEnabled = false

    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openWindow) private var openWindow

    private let panelWidth: CGFloat = 760
    private let panelHeight: CGFloat = 640
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    private var accentPalette: [Color] {
        themeStore.accentPalette
    }

    private var isDarkTheme: Bool {
        themeStore.resolvedColorScheme(systemColorScheme: systemColorScheme) == .dark
    }

    private var accentColor: Color {
        themeStore.accentColor
    }

    private var panelFillColor: Color {
        isDarkTheme ? Color(red: 0.09, green: 0.09, blue: 0.10) : .white
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
        accentColor.opacity(isDarkTheme ? 0.30 : 0.20)
    }

    private var selectedTabStrokeColor: Color {
        accentColor.opacity(isDarkTheme ? 0.46 : 0.45)
    }

    private var githubSectionFillColor: Color {
        isDarkTheme ? Color.white.opacity(0.03) : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var githubSectionStrokeColor: Color {
        isDarkTheme ? Color.white.opacity(0.12) : Color.black.opacity(0.11)
    }

    private var githubInputFillColor: Color {
        isDarkTheme ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
    }

    private var githubInputStrokeColor: Color {
        isDarkTheme ? Color.white.opacity(0.16) : Color.black.opacity(0.12)
    }

    private var githubPrimaryButtonTint: Color {
        Color(red: 0.19, green: 0.53, blue: 0.88)
    }

    private var githubSecondaryButtonFillColor: Color {
        isDarkTheme
        ? Color(red: 0.25, green: 0.25, blue: 0.27)
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

    private var appVersionLabel: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let resolvedShortVersion = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedBuildVersion = buildVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !resolvedShortVersion.isEmpty, !resolvedBuildVersion.isEmpty, resolvedShortVersion != resolvedBuildVersion {
            return "\(resolvedShortVersion) (\(resolvedBuildVersion))"
        }

        if !resolvedShortVersion.isEmpty {
            return resolvedShortVersion
        }

        if !resolvedBuildVersion.isEmpty {
            return resolvedBuildVersion
        }

        return "Unknown"
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
                ),
                windowLevel: .floating
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
                applyWindowLevel(window)
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
                Text("Settings")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .frame(height: 36, alignment: .center)

                Spacer()
            }
            .frame(height: 36)
            .background(SettingsWindowDragRegion())

            HStack(spacing: 8) {
                Button(action: openAppUpdatePage) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.trianglehead.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Update App")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(cardFillColor)
                            .overlay(
                                Capsule()
                                    .stroke(cardStrokeColor, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isAppUpdateEnabled)
                .opacity(isAppUpdateEnabled ? 1 : 0.58)
                .help(isAppUpdateEnabled ? "Open latest release page." : "Update temporarily disabled.")

                Button(action: openTaskWindow) {
                    SettingsHeaderIcon(
                        symbol: "text.pad.header.badge.plus",
                        isDarkTheme: isDarkTheme,
                        accentColor: accentColor
                    )
                }
                .buttonStyle(.plain)
                .help("Open Kubbo Task")

                Button(action: openRepositoryWindow) {
                    SettingsHeaderIcon(
                        symbol: "selection.pin.in.out",
                        isDarkTheme: isDarkTheme,
                        accentColor: accentColor
                    )
                }
                .buttonStyle(.plain)
                .help("Open Repository")

                Button(action: toggleWindowPin) {
                    SettingsHeaderIcon(
                        symbol: isWindowPinned ? "pin.fill" : "pin",
                        isActive: isWindowPinned,
                        isDarkTheme: isDarkTheme,
                        accentColor: accentColor
                    )
                }
                .buttonStyle(.plain)
                .help(isWindowPinned ? "Unpin window" : "Pin window on top")

                Button(action: closeSettingsWindow) {
                    SettingsHeaderIcon(
                        symbol: "xmark",
                        isDarkTheme: isDarkTheme,
                        accentColor: accentColor
                    )
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
                prompt: Text("Search settings...").foregroundColor(searchPlaceholderColor)
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
                Text("Settings active")
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

            sectionTitle("UPDATE")
            settingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Current version: \(appVersionLabel)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Text("Click below to open the latest release and update the app.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    Button(action: openAppUpdatePage) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.trianglehead.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Update App")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
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
                    .buttonStyle(.plain)
                    .disabled(!isAppUpdateEnabled)
                    .opacity(isAppUpdateEnabled ? 1 : 0.58)
                    .help(isAppUpdateEnabled ? "Open latest release page." : "Update temporarily disabled.")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var appearanceContent: some View {
        let selectedTheme = viewModel.selectedThemeMode

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("THEME")
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
                                        .stroke(mode == selectedTheme ? accentColor : cardStrokeColor.opacity(0.85), lineWidth: mode == selectedTheme ? 2 : 1)
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

            sectionTitle("ACCENT COLOR")
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
                        githubLocalRepositoriesSection
                    }

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

                        if let localRepositoriesRootErrorMessage {
                            Text(localRepositoriesRootErrorMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(0.85))
                        }

                        if let githubErrorMessage = viewModel.githubErrorMessage {
                            Text(githubErrorMessage)
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

    private var githubLocalRepositoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local Repositories Folder")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)

            Text("Used by Open in Finder and Open in Terminal.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)

            if let localRootPath = viewModel.localRepositoriesRootPath,
               !localRootPath.isEmpty {
                Text(localRootPath)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryTextColor)
                    .textSelection(.enabled)
                    .lineLimit(2)
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
            } else {
                Text("No local folder configured.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(tertiaryTextColor)
            }

            HStack(spacing: 10) {
                githubSecondaryButton("Choose Folder") {
                    chooseLocalRepositoriesFolder()
                }

                githubSecondaryButton(
                    "Clear Folder",
                    isDisabled: !viewModel.hasLocalRepositoriesRootConfigured
                ) {
                    viewModel.clearLocalRepositoriesRoot()
                }
            }
        }
    }

    private func openGitHubDevicePage() {
        if let verificationURL = viewModel.githubVerificationURL ?? URL(string: gitHubDeviceURLString) {
            NSWorkspace.shared.open(verificationURL)
        }
    }

    private func openAppUpdatePage() {
        guard let releaseURL = URL(string: "https://github.com/openkubbo/openkubbo/releases/latest") else {
            return
        }

        NSWorkspace.shared.open(releaseURL)
    }

    private func openRepositoryWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "repository")
    }

    private func openTaskWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "task")
    }

    private func chooseLocalRepositoriesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select local repositories folder"
        panel.message = "Choose the folder that contains your local Git repositories."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedURL = panel.url {
            do {
                try viewModel.setLocalRepositoriesRoot(url: selectedURL)
                localRepositoriesRootErrorMessage = nil
            } catch {
                localRepositoriesRootErrorMessage = "Unable to save the selected folder."
            }
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
                .tint(accentColor)
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

    private func toggleWindowPin() {
        isWindowPinned.toggle()
        applyWindowLevel(hostWindow)
    }

    private func applyWindowLevel(_ window: NSWindow?) {
        guard let window else { return }
        window.level = isWindowPinned ? .floating : .normal
    }
}
