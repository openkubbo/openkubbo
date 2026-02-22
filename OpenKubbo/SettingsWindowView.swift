//
//  SettingsWindowView.swift
//  OpenKubbo
//
//  Created by Tarik Villalobos on 2/21/26.
//

import SwiftUI
import AppKit

struct SettingsWindowView: View {
    @State private var selectedSection: SettingsSidebarSection = .shortcuts

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selectedSection: $selectedSection)
                .frame(width: 286)
                .background(SettingsPalette.sidebarBackground)

            Divider()
                .overlay(SettingsPalette.divider)

            VStack(spacing: 0) {
                HStack {
                    Text(selectedSection.windowTitle)
                        .font(.system(size: 40, weight: .semibold))
                        .kerning(-0.8)
                        .foregroundStyle(SettingsPalette.primaryText)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 38)
                .frame(height: 88)
                .background(SettingsPalette.surface)

                Divider()
                    .overlay(SettingsPalette.divider)

                SettingsPanePlaceholder()
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
}

private struct SettingsSidebar: View {
    @Binding var selectedSection: SettingsSidebarSection

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                TrafficLightsRow()

                SearchBarPlaceholder()

                VStack(spacing: 8) {
                    ForEach(SettingsSidebarSection.allCases) { section in
                        SettingsSidebarRow(
                            section: section,
                            isSelected: selectedSection == section
                        ) {
                            selectedSection = section
                        }
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 0)

            Divider()
                .overlay(SettingsPalette.divider)

            AccountFooter()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
    }
}

private struct TrafficLightsRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                .frame(width: 12, height: 12)

            Circle()
                .fill(Color(red: 1.0, green: 0.75, blue: 0.18))
                .frame(width: 12, height: 12)

            Circle()
                .fill(Color(red: 0.17, green: 0.79, blue: 0.32))
                .frame(width: 12, height: 12)

            Spacer(minLength: 0)
        }
    }
}

private struct SearchBarPlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(SettingsPalette.secondaryLabel)

            Text("Buscar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SettingsPalette.secondaryLabel)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SettingsPalette.searchBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
            HStack(spacing: 12) {
                SidebarIcon(systemName: section.systemImage, fallback: section.fallbackIcon)

                Text(section.rawValue)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? SettingsPalette.primaryText : SettingsPalette.secondaryLabel)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor)
            )
            .shadow(
                color: isSelected ? SettingsPalette.selectedSidebarShadow : .clear,
                radius: isSelected ? 12 : 0,
                x: 0,
                y: isSelected ? 6 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .font(.system(size: 19, weight: .regular))
                    .frame(width: 18, height: 18)
            } else {
                Text(fallback)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(width: 18, height: 18)
            }
        }
        .foregroundStyle(SettingsPalette.icon)
    }
}

private struct AccountFooter: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.8))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("GlassUser")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SettingsPalette.primaryText)

                Text("PRO ACCOUNT")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(SettingsPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SettingsPanePlaceholder: View {
    var body: some View {
        Color.clear
            .background(SettingsPalette.contentBackground)
    }
}

private struct SettingsWindowChromeConfigurator: NSViewRepresentable {
    private static let fixedWindowSize = NSSize(width: 860, height: 640)

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
        window.styleMask.remove(.resizable)
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = SettingsPalette.surfaceNSColor
        window.minSize = Self.fixedWindowSize
        window.maxSize = Self.fixedWindowSize
        if window.frame.size != Self.fixedWindowSize {
            window.setContentSize(Self.fixedWindowSize)
        }

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
        switch self {
        case .general:
            return "Geral"
        case .appearance:
            return "Aparência"
        case .codexCLI:
            return "Codex CLI"
        case .shortcuts:
            return "Atalhos de Teclado"
        }
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

private enum SettingsPalette {
    static let surface = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let surfaceNSColor = NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
    static let sidebarBackground = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let contentBackground = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let searchBackground = Color(red: 0.95, green: 0.96, blue: 0.98)

    static let shellBorder = Color(red: 0.76, green: 0.79, blue: 0.87)
    static let divider = Color(red: 0.79, green: 0.82, blue: 0.89)

    static let primaryText = Color(red: 0.10, green: 0.14, blue: 0.22)
    static let secondaryText = Color(red: 0.57, green: 0.61, blue: 0.69)
    static let secondaryLabel = Color(red: 0.33, green: 0.40, blue: 0.51)
    static let icon = Color(red: 0.43, green: 0.48, blue: 0.58)

    static let selectedSidebar = Color(red: 0.76, green: 0.75, blue: 0.90)
    static let selectedSidebarShadow = Color.black.opacity(0.13)
    static let hoverSidebar = Color.black.opacity(0.05)
}
