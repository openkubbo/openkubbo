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
            VStack(alignment: .leading, spacing: 4) {
                ForEach(topMenuItems) { item in
                    Button {
                        handleMenuSelection(item.title)
                    } label: {
                        HStack(spacing: 8) {
                            MenuItemIcon(systemName: item.systemImage, fallback: item.fallbackIcon)
                            Text(item.title)
                        }
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .pointingHandCursor()
                }

                Divider()
                    .padding(.vertical, 4)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .pointingHandCursor()
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
    }

    private func handleMenuSelection(_ item: String) {
        // Wire each option to its destination as features are implemented.
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

private struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}
