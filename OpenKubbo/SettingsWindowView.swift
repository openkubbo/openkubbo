//
//  SettingsWindowView.swift
//  OpenKubbo
//
//  Created by Tarik Villalobos on 2/21/26.
//

import SwiftUI
import AppKit

struct SettingsWindowView: View {
    @State private var selectedSection: SettingsSidebarSection = .appearance
    @State private var selectedAppearance: AppearanceOption = .light
    @State private var selectedAccentColor: AccentColorOption = .blue
    @State private var selectedIconSize: IconSizeOption = .medium
    @State private var selectedScrollbarBehavior: ScrollbarBehavior = .automatic

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selectedSection: $selectedSection)
                .frame(width: 470)
                .background(SettingsPalette.sidebarBackground)

            Divider()
                .overlay(SettingsPalette.divider)

            VStack(spacing: 0) {
                HStack {
                    Text(selectedSection.windowTitle)
                        .font(.system(size: 22, weight: .semibold))
                        .kerning(-0.6)
                        .foregroundStyle(SettingsPalette.primaryText)

                    Spacer()
                }
                .padding(.horizontal, 42)
                .padding(.vertical, 34)

                Divider()
                    .overlay(SettingsPalette.divider)

                mainPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(SettingsPalette.contentBackground)
        }
        .background(SettingsPalette.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            SettingsWindowChromeConfigurator()
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var mainPane: some View {
        switch selectedSection {
        case .appearance:
            AppearancePane(
                selectedAppearance: $selectedAppearance,
                selectedAccentColor: $selectedAccentColor,
                selectedIconSize: $selectedIconSize,
                selectedScrollbarBehavior: $selectedScrollbarBehavior
            )
        case .shortcuts:
            ShortcutsPane()
        default:
            PlaceholderPane(title: selectedSection.windowTitle)
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedSection: SettingsSidebarSection

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                SearchBarPlaceholder()

                VStack(spacing: 10) {
                    ForEach(SettingsSidebarSection.allCases) { section in
                        SettingsSidebarRow(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            selectedSection = section
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer(minLength: 0)

            Divider()
                .overlay(SettingsPalette.divider)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16))
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.86))
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GlassUser")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SettingsPalette.primaryText)
                    Text("PRO ACCOUNT")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(SettingsPalette.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
}

private struct SearchBarPlaceholder: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(SettingsPalette.secondaryLabel)

            Text("Buscar")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SettingsPalette.secondaryLabel)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(SettingsPalette.contentBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(SettingsPalette.divider, lineWidth: 1)
        )
    }
}

private struct SettingsSidebarRow: View {
    let section: SettingsSidebarSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SidebarIcon(systemName: section.systemImage, fallback: section.fallbackIcon)

                Text(section.rawValue)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .medium))
                    .kerning(-0.3)
                    .foregroundStyle(isSelected ? SettingsPalette.primaryText : SettingsPalette.secondaryLabel)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(backgroundColor)
            )
            .shadow(
                color: isSelected ? SettingsPalette.selectedSidebarShadow : .clear,
                radius: isSelected ? 16 : 0,
                x: 0,
                y: isSelected ? 7 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var backgroundColor: Color {
        if isSelected {
            return SettingsPalette.selectedSidebar
        }

        if isHovering {
            return SettingsPalette.hoverSidebar
        }

        return .clear
    }
}

private struct SidebarIcon: View {
    let systemName: String
    let fallback: String

    var body: some View {
        Group {
            if NSImage(systemSymbolName: systemName, accessibilityDescription: nil) != nil {
                Image(systemName: systemName)
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: 28, height: 24)
            } else {
                Text(fallback)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .frame(width: 28, height: 24)
            }
        }
        .foregroundStyle(SettingsPalette.icon)
    }
}

private struct AppearancePane: View {
    @Binding var selectedAppearance: AppearanceOption
    @Binding var selectedAccentColor: AccentColorOption
    @Binding var selectedIconSize: IconSizeOption
    @Binding var selectedScrollbarBehavior: ScrollbarBehavior

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 52) {
                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel("APARÊNCIA")

                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 14) {
                            ThemeOptionCard(
                                option: .light,
                                selectedOption: selectedAppearance,
                                label: "Clara"
                            ) {
                                selectedAppearance = .light
                            }

                            Text("Clara")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(SettingsPalette.secondaryLabel)
                        }

                        VStack(spacing: 14) {
                            ThemeOptionCard(
                                option: .dark,
                                selectedOption: selectedAppearance,
                                label: "Escura"
                            ) {
                                selectedAppearance = .dark
                            }

                            Text("Escura")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(SettingsPalette.secondaryLabel)
                        }

                        Button {
                            selectedAppearance = .automatic
                        } label: {
                            Text("Automática")
                                .font(.system(size: 22, weight: selectedAppearance == .automatic ? .semibold : .medium))
                                .foregroundStyle(selectedAppearance == .automatic ? SettingsPalette.primaryText : SettingsPalette.secondaryLabel)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .padding(.top, 52)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                }

                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel("COR DE DESTAQUE")

                    HStack(spacing: 24) {
                        ForEach(AccentColorOption.allCases) { option in
                            AccentColorSwatch(
                                color: option.color,
                                isSelected: selectedAccentColor == option
                            ) {
                                selectedAccentColor = option
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel("TAMANHO DOS ÍCONES")

                    SegmentedPillControl(
                        options: IconSizeOption.allCases,
                        selectedOption: $selectedIconSize
                    )
                    .frame(maxWidth: 980)
                }

                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel("BARRAS DE ROLAGEM")

                    VStack(spacing: 14) {
                        ScrollbarOptionRow(
                            title: "Automaticamente com base no mouse ou trackpad",
                            isSelected: selectedScrollbarBehavior == .automatic
                        ) {
                            selectedScrollbarBehavior = .automatic
                        }

                        ScrollbarOptionRow(
                            title: "Sempre",
                            isSelected: selectedScrollbarBehavior == .always
                        ) {
                            selectedScrollbarBehavior = .always
                        }
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 42)
            .padding(.bottom, 58)
        }
        .scrollIndicators(.hidden)
        .background(SettingsPalette.contentBackground)
    }
}

private struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .tracking(2.1)
            .foregroundStyle(SettingsPalette.secondaryText)
    }
}

private struct ThemeOptionCard: View {
    let option: AppearanceOption
    let selectedOption: AppearanceOption
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(cardFill)
                .frame(width: 304, height: 154)
                .overlay(themePreview.padding(18))
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(borderColor, lineWidth: selectedOption == option ? 5 : 1.2)
                )
                .shadow(color: Color.black.opacity(option == .light ? 0.12 : 0.22), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var cardFill: Color {
        switch option {
        case .light:
            return Color.white
        case .dark:
            return Color(red: 0.05, green: 0.05, blue: 0.06)
        case .automatic:
            return SettingsPalette.cardBackground
        }
    }

    private var borderColor: Color {
        if selectedOption == option {
            return Color.accentColor.opacity(0.55)
        }

        return option == .dark
            ? Color.white.opacity(0.08)
            : SettingsPalette.divider
    }

    @ViewBuilder
    private var themePreview: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(option == .dark ? Color.black.opacity(0.88) : Color.black.opacity(0.08))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(option == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08))
                        .frame(width: 160, height: 24)

                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(option == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.09))
                        .frame(width: 122, height: 24)
                }
                .padding(18)
            }
    }
}

private struct AccentColorSwatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)

                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 15, height: 15)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? SettingsPalette.icon : Color.clear, lineWidth: 4)
                    .padding(-8)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SegmentedPillControl<Option: CaseIterable & Identifiable & RawRepresentable>: View where Option.RawValue == String {
    let options: [Option]
    @Binding var selectedOption: Option

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    selectedOption = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selectedOption == option ? Color.white : SettingsPalette.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selectedOption == option ? Color.accentColor.opacity(0.9) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(SettingsPalette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(SettingsPalette.divider, lineWidth: 1)
        )
    }
}

private struct ScrollbarOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(isSelected ? Color.accentColor.opacity(0.92) : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : SettingsPalette.secondaryText, lineWidth: 2)
                    )

                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primaryText)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(SettingsPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(SettingsPalette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PlaceholderPane: View {
    let title: String

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(SettingsPalette.primaryText)

            Text("Conteúdo desta seção será adicionado em seguida.")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SettingsPalette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsPalette.contentBackground)
    }
}

private struct ShortcutsPane: View {
    private let generalItems = [
        ShortcutItem(title: "Nova Tarefa", keys: ["↩"]),
        ShortcutItem(title: "Nova Ideia", keys: ["⌘", "I"]),
        ShortcutItem(title: "Configurações", keys: ["⌘", ","])
    ]

    private let windowItems = [
        ShortcutItem(title: "Duplicar Janela", keys: ["⌘", "D"]),
        ShortcutItem(title: "Fechar Janela", keys: ["⌘", "W"])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 42) {
                ShortcutSection(title: "GERAL", items: generalItems)
                ShortcutSection(title: "GERENCIAMENTO DE JANELAS", items: windowItems)
            }
            .padding(.horizontal, 42)
            .padding(.top, 34)
            .padding(.bottom, 38)
        }
        .scrollIndicators(.hidden)
        .background(SettingsPalette.contentBackground)
    }
}

private struct ShortcutSection: View {
    let title: String
    let items: [ShortcutItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title)

            VStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { index in
                    ShortcutRow(item: items[index])

                    if index != items.indices.last {
                        Divider()
                            .overlay(SettingsPalette.divider)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(SettingsPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(SettingsPalette.divider, lineWidth: 1)
            )
        }
    }
}

private struct ShortcutRow: View {
    let item: ShortcutItem

    var body: some View {
        HStack {
            Text(item.title)
                .font(.system(size: 20, weight: .semibold))
                .kerning(-0.4)
                .foregroundStyle(SettingsPalette.primaryText)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                ForEach(item.keys, id: \.self) { key in
                    KeycapView(label: key)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}

private struct KeycapView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(SettingsPalette.primaryText)
            .frame(minWidth: 52, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(SettingsPalette.keycapBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.09), radius: 0, x: 0, y: 2)
    }
}

private struct ShortcutItem {
    let title: String
    let keys: [String]
}

private struct SettingsWindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = SettingsPalette.surfaceNSColor

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

private enum SettingsSidebarSection: String, CaseIterable, Identifiable {
    case general = "Geral"
    case appearance = "Aparência"
    case codexCLI = "Codex CLI"
    case shortcuts = "Atalhos"

    var id: String { rawValue }

    var windowTitle: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .appearance:
            return "display"
        case .codexCLI:
            return "terminal"
        case .shortcuts:
            return "command"
        }
    }

    var fallbackIcon: String {
        switch self {
        case .general:
            return "G"
        case .appearance:
            return "A"
        case .codexCLI:
            return ">_"
        case .shortcuts:
            return "^"
        }
    }
}

private enum AppearanceOption {
    case light
    case dark
    case automatic
}

private enum AccentColorOption: CaseIterable, Identifiable {
    case blue
    case indigo
    case purple
    case pink
    case gray

    var id: String {
        switch self {
        case .blue:
            return "blue"
        case .indigo:
            return "indigo"
        case .purple:
            return "purple"
        case .pink:
            return "pink"
        case .gray:
            return "gray"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return Color(red: 0.40, green: 0.55, blue: 0.95)
        case .indigo:
            return Color(red: 0.37, green: 0.56, blue: 0.94)
        case .purple:
            return Color(red: 0.66, green: 0.42, blue: 0.92)
        case .pink:
            return Color(red: 0.89, green: 0.39, blue: 0.67)
        case .gray:
            return Color(red: 0.57, green: 0.60, blue: 0.67)
        }
    }
}

private enum IconSizeOption: String, CaseIterable, Identifiable {
    case small = "Pequeno"
    case medium = "Médio"
    case large = "Grande"

    var id: String { rawValue }
}

private enum ScrollbarBehavior {
    case automatic
    case always
}

private enum SettingsPalette {
    static let surface = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let surfaceNSColor = NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
    static let sidebarBackground = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let contentBackground = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let cardBackground = Color(red: 0.94, green: 0.94, blue: 0.96)

    static let shellBorder = Color(red: 0.78, green: 0.80, blue: 0.87)
    static let divider = Color(red: 0.79, green: 0.82, blue: 0.89)
    static let keycapBorder = Color(red: 0.84, green: 0.85, blue: 0.90)

    static let primaryText = Color(red: 0.10, green: 0.14, blue: 0.22)
    static let secondaryText = Color(red: 0.55, green: 0.60, blue: 0.68)
    static let secondaryLabel = Color(red: 0.33, green: 0.39, blue: 0.50)
    static let icon = Color(red: 0.42, green: 0.47, blue: 0.56)

    static let selectedSidebar = Color(red: 0.76, green: 0.75, blue: 0.90)
    static let selectedSidebarShadow = Color.black.opacity(0.14)
    static let hoverSidebar = Color.black.opacity(0.05)
}
