//
//  SettingsWindowView.swift
//  OpenKubbo
//
//  Created by Tarik Villalobos on 2/21/26.
//

import SwiftUI
import AppKit

struct SettingsWindowView: View {
    @State private var selectedSection: SettingsSidebarSection = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selectedSection: $selectedSection)
                .frame(width: 340)

            Divider()

            Color(nsColor: .windowBackgroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedSection: SettingsSidebarSection

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                SearchBarPlaceholder()

                VStack(spacing: 6) {
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
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Spacer(minLength: 0)

            Divider()

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GlassUser")
                        .font(.system(size: 17, weight: .semibold))
                    Text("PRO ACCOUNT")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct SearchBarPlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.secondary)

            Text("Buscar")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
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
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.78))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            return Color.accentColor.opacity(0.22)
        }

        if isHovering {
            return Color.primary.opacity(0.1)
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
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 28, height: 24)
            } else {
                Text(fallback)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .frame(width: 28, height: 24)
            }
        }
        .foregroundStyle(Color.primary.opacity(0.8))
    }
}

private enum SettingsSidebarSection: String, CaseIterable, Identifiable {
    case general = "Geral"
    case appearance = "Aparência"
    case codexCLI = "Codex CLI"
    case shortcuts = "Atalhos"

    var id: String { rawValue }

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
