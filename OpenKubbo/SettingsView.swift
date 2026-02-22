//
//  SettingsView.swift
//  open-tasks
//

import AppKit
import Combine
import ObjectiveC.runtime
import SwiftUI

enum AppTheme {
    case light
    case dark
    case automatic
}

@MainActor
final class AppThemeStore: ObservableObject {
    @Published var selectedTheme: AppTheme = .automatic

    func resolvedColorScheme(systemColorScheme: ColorScheme) -> ColorScheme {
        switch selectedTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .automatic:
            return systemColorScheme
        }
    }
}

struct SettingsView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "Geral"
        case appearance = "Aparência"
        case codexCLI = "Codex CLI"
        case shortcuts = "Atalhos"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general:
                return "slider.horizontal.3"
            case .appearance:
                return "desktopcomputer"
            case .codexCLI:
                return "chevron.left.forwardslash.chevron.right"
            case .shortcuts:
                return "command"
            }
        }
    }

    private enum ThemeMode: String, CaseIterable, Identifiable {
        case light = "Clara"
        case dark = "Escura"
        case automatic = "Automática"

        var id: String { rawValue }

        init(appTheme: AppTheme) {
            switch appTheme {
            case .light:
                self = .light
            case .dark:
                self = .dark
            case .automatic:
                self = .automatic
            }
        }

        var appTheme: AppTheme {
            switch self {
            case .light:
                return .light
            case .dark:
                return .dark
            case .automatic:
                return .automatic
            }
        }
    }

    private struct ShortcutItem: Identifiable {
        let id = UUID()
        let name: String
        let keys: [String]
    }

    private struct ShortcutGroup: Identifiable {
        let id = UUID()
        let title: String
        let items: [ShortcutItem]
    }

    private let panelWidth: CGFloat = 760
    private let panelHeight: CGFloat = 640
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    @State private var selectedTab: SettingsTab = .general
    @State private var searchText = ""
    @State private var hostWindow: NSWindow?
    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var launchAtLogin = false
    @State private var reopenPreviousWindows = true
    @State private var playCompletionSound = true
    @State private var hapticsEnabled = true
    @State private var appLanguage = "Português (Brasil)"

    @State private var selectedAccentColorIndex = 0

    @State private var selectedModel = "Gemini 1.5 Pro"
    @State private var temperature = 0.7
    @State private var terminalSuggestionsEnabled = true
    @State private var automaticErrorAnalysis = false
    @State private var syncProfilesEnabled = true

    private let executablePath = "/usr/local/bin/codex"
    private let apiKeyMasked = "••••••••••••••••"
    private let models = ["Gemini 1.5 Pro", "GPT-4.1", "Claude 3.7 Sonnet"]

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

    private var shortcutGroups: [ShortcutGroup] {
        [
            ShortcutGroup(
                title: "GERAL",
                items: [
                    ShortcutItem(name: "Nova Tarefa", keys: ["↩"]),
                    ShortcutItem(name: "Configurações", keys: ["⌘", ","]),
                    ShortcutItem(name: "Buscar", keys: ["⌘", "F"])
                ]
            ),
            ShortcutGroup(
                title: "JANELA",
                items: [
                    ShortcutItem(name: "Duplicar Janela", keys: ["⌘", "D"]),
                    ShortcutItem(name: "Fechar Janela", keys: ["⌘", "W"]),
                    ShortcutItem(name: "Minimizar", keys: ["⌘", "M"])
                ]
            ),
            ShortcutGroup(
                title: "TAREFAS",
                items: [
                    ShortcutItem(name: "Editar Tarefa", keys: ["⌘", "E"]),
                    ShortcutItem(name: "Concluir Tarefa", keys: ["⌘", "↩"]),
                    ShortcutItem(name: "Excluir Tarefa", keys: ["⌘", "⌫"])
                ]
            )
        ]
    }

    private var visibleTabs: [SettingsTab] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SettingsTab.allCases
        }
        return SettingsTab.allCases.filter { tab in
            tab.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var activeTab: SettingsTab {
        if visibleTabs.contains(selectedTab) {
            return selectedTab
        }
        return visibleTabs.first ?? .general
    }

    private var selectedThemeMode: ThemeMode {
        ThemeMode(appTheme: themeStore.selectedTheme)
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
                text: $searchText,
                prompt: Text("Buscar ajustes...").foregroundColor(searchPlaceholderColor)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(primaryTextColor)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
            if visibleTabs.isEmpty {
                EmptySettingsStateView(isDarkTheme: isDarkTheme)
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleTabs) { tab in
                        sidebarTabButton(tab)
                    }
                }
            }
        }
    }

    private func sidebarTabButton(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(activeTab == tab ? primaryTextColor : secondaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(activeTab == tab ? selectedTabFillColor : cardFillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(activeTab == tab ? selectedTabStrokeColor : cardStrokeColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch activeTab {
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

                Text(activeTab.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("INICIALIZAÇÃO")
            settingsCard {
                toggleRow(icon: "power", title: "Iniciar ao ligar o Mac", isOn: $launchAtLogin)
                rowDivider
                toggleRow(title: "Reabrir janelas anteriores", isOn: $reopenPreviousWindows)
            }

            sectionTitle("SONS E FEEDBACK")
            settingsCard {
                toggleRow(icon: "speaker.wave.2", title: "Reproduzir som ao concluir", isOn: $playCompletionSound)
                rowDivider
                toggleRow(title: "Feedback tátil (Haptics)", isOn: $hapticsEnabled)
            }

            sectionTitle("IDIOMA")
            settingsCard {
                HStack(spacing: 12) {
                    Text("Idioma do App")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Spacer()

                    Picker("", selection: $appLanguage) {
                        Text("Português (Brasil)").tag("Português (Brasil)")
                        Text("English (US)").tag("English (US)")
                        Text("Español").tag("Español")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 220)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            sectionTitle("DADOS")
            settingsCard {
                HStack(spacing: 10) {
                    Text("Armazenamento Local")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Spacer()

                    Text("2.4 GB")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var appearanceContent: some View {
        let selectedTheme = selectedThemeMode

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("TEMA")
            HStack(spacing: 10) {
                ForEach(ThemeMode.allCases) { mode in
                    Button {
                        themeStore.selectedTheme = mode.appTheme
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
                        selectedAccentColorIndex = index
                    } label: {
                        Circle()
                            .fill(accentPalette[index])
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke((isDarkTheme ? Color.white.opacity(0.86) : Color.black.opacity(0.82)).opacity(index == selectedAccentColorIndex ? 1 : 0), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var codexContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CONEXÃO")
            settingsCard {
                rowValue(title: "Caminho do Executável", value: executablePath)
                rowDivider
                rowValue(title: "Chave de API", value: apiKeyMasked)
            }

            Text("O caminho deve apontar para o binário instalado via Homebrew ou npm.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(tertiaryTextColor)
                .padding(.horizontal, 2)

            sectionTitle("INFERÊNCIA")
            settingsCard {
                HStack {
                    Text("Modelo Principal")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Spacer()

                    Picker("", selection: $selectedModel) {
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 210)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                HStack(spacing: 10) {
                    Text("Temperatura")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Slider(value: $temperature, in: 0...1, step: 0.1)
                        .tint(Color(red: 0.39, green: 0.44, blue: 0.99))

                    Text(String(format: "%.1f", temperature))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 32)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            sectionTitle("INTEGRAÇÃO")
            settingsCard {
                toggleRow(title: "Sugestões Inteligentes no Terminal", isOn: $terminalSuggestionsEnabled)
                rowDivider
                toggleRow(title: "Análise de Erros Automática", isOn: $automaticErrorAnalysis)
                rowDivider
                toggleRow(title: "Sincronizar Perfis", isOn: $syncProfilesEnabled)
            }
        }
    }

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(shortcutGroups) { group in
                sectionTitle(group.title)
                settingsCard {
                    ForEach(group.items.indices, id: \.self) { index in
                        let item = group.items[index]
                        HStack {
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)

                            Spacer()

                            ShortcutKeysView(keys: item.keys, isDarkTheme: isDarkTheme)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        if index < group.items.count - 1 {
                            rowDivider
                        }
                    }
                }
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

private struct SettingsHeaderIcon: View {
    let symbol: String
    var isActive = false
    var isDarkTheme = false

    private var symbolColor: Color {
        isDarkTheme ? .white.opacity(isActive ? 0.84 : 0.66) : .black.opacity(isActive ? 0.82 : 0.62)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.21, blue: 0.25) : .white
    }

    private var strokeColor: Color {
        if isActive {
            return Color(red: 0.42, green: 0.41, blue: 0.80).opacity(0.45)
        }
        return isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.10)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: 42, height: 42)
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

private struct ShortcutKeysView: View {
    let keys: [String]
    var isDarkTheme = false

    private var textColor: Color {
        isDarkTheme ? .white.opacity(0.84) : .black.opacity(0.78)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.21, blue: 0.25) : .white
    }

    private var strokeColor: Color {
        isDarkTheme ? .white.opacity(0.12) : .black.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)
                    .frame(minWidth: 26)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(strokeColor, lineWidth: 1)
                            )
                    )
            }
        }
    }
}

private struct EmptySettingsStateView: View {
    var isDarkTheme = false

    private var textColor: Color {
        isDarkTheme ? .white.opacity(0.58) : .black.opacity(0.50)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.21, blue: 0.25) : .white
    }

    private var strokeColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
            Text("Nenhum ajuste encontrado")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        )
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    let targetSize: CGSize
    let onResolve: (NSWindow) -> Void
    private static var patchedWindowClasses: Set<ObjectIdentifier> = []

    init(targetSize: CGSize, onResolve: @escaping (NSWindow) -> Void = { _ in }) {
        self.targetSize = targetSize
        self.onResolve = onResolve
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window)
            onResolve(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window)
            onResolve(window)
        }
    }

    private func configure(_ window: NSWindow) {
        ensureWindowCanBecomeKey(window)

        if window.identifier?.rawValue != "glassdo.settings.window" {
            window.identifier = NSUserInterfaceItemIdentifier("glassdo.settings.window")
            window.styleMask = [.borderless, .fullSizeContentView]
            window.isMovableByWindowBackground = false
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.level = .floating
            window.collectionBehavior = [.fullScreenAuxiliary]
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }

        window.minSize = NSSize(width: 620, height: 520)
        let desiredSize = NSSize(width: targetSize.width, height: targetSize.height)
        if window.frame.size != desiredSize {
            window.setContentSize(desiredSize)
        }
    }

    private func ensureWindowCanBecomeKey(_ window: NSWindow) {
        guard let windowClass = object_getClass(window) else { return }
        let classID = ObjectIdentifier(windowClass)
        guard !Self.patchedWindowClasses.contains(classID) else { return }

        let canBecomeKey: @convention(block) (AnyObject) -> Bool = { _ in true }
        let canBecomeMain: @convention(block) (AnyObject) -> Bool = { _ in true }

        class_addMethod(
            windowClass,
            #selector(getter: NSWindow.canBecomeKey),
            imp_implementationWithBlock(canBecomeKey),
            "B@:"
        )
        class_addMethod(
            windowClass,
            #selector(getter: NSWindow.canBecomeMain),
            imp_implementationWithBlock(canBecomeMain),
            "B@:"
        )

        Self.patchedWindowClasses.insert(classID)
    }
}

private struct SettingsWindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SettingsDragRegionNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class SettingsDragRegionNSView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        discardCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        window?.performDrag(with: event)
    }
}
