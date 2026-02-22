//
//  OpenKubboApp.swift
//  OpenKubbo
//
//  Created by Tarik Villalobos on 2/21/26.
//

import SwiftUI
import AppKit

@main
struct OpenKubboApp: App {
    @Environment(\.openWindow) private var openWindow

    private struct TopMenuItem: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let fallbackIcon: String
    }

    private let topMenuItems = [
        TopMenuItem(id: "theme", title: "Theme mode", systemImage: "sun.max", fallbackIcon: "L"),
        TopMenuItem(id: "new-task", title: "New Task", systemImage: "text.pad.header.badge.plus", fallbackIcon: "+"),
        TopMenuItem(id: "repository", title: "Repository", systemImage: "selection.pin.in.out", fallbackIcon: "git"),
        TopMenuItem(id: "terminal", title: "Terminal", systemImage: "terminal", fallbackIcon: ">_"),
        TopMenuItem(id: "agent", title: "Kubbo Agent", systemImage: "cpu", fallbackIcon: "bot"),
        TopMenuItem(id: "settings", title: "Settings", systemImage: "gearshape", fallbackIcon: "S")
    ]

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(topMenuItems) { item in
                    MenuActionRow(
                        title: item.title,
                        systemImage: item.systemImage,
                        fallbackIcon: item.fallbackIcon
                    ) {
                        handleMenuSelection(item.id)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                MenuActionRow(title: "Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(10)
            .frame(width: 220)
        } label: {
            Image("OpenKubbo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .accessibilityLabel("OpenKubbo")
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsWindowView()
        }
        .defaultSize(width: 720, height: 520)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }

    private func handleMenuSelection(_ itemID: String) {
        switch itemID {
        case "settings":
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        default:
            break
        }
    }
}

private struct MenuActionRow: View {
    let title: String
    let systemImage: String?
    let fallbackIcon: String?
    let action: () -> Void

    @State private var isHovering = false

    init(title: String, systemImage: String? = nil, fallbackIcon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.fallbackIcon = fallbackIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage, let fallbackIcon {
                    MenuItemIcon(systemName: systemImage, fallback: fallbackIcon)
                }

                Text(title)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.12) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
}

private struct MenuItemIcon: View {
    let systemName: String
    let fallback: String

    var body: some View {
        Group {
            if NSImage(systemSymbolName: systemName, accessibilityDescription: nil) != nil {
                Image(systemName: systemName)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(fallback)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
        }
        .frame(width: 14, height: 14)
    }
}
