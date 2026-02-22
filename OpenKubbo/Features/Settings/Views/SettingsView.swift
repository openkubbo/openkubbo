import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var hostWindow: NSWindow?

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

    private var rowDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 1)
            .padding(.horizontal, 12)
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
