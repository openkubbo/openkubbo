import AppKit
import SwiftUI

struct MenuBarExtraView: View {
    let viewModel: MenuBarViewModel
    let onSelect: (MenuBarAction) -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(viewModel.items) { item in
                MenuActionRowView(
                    title: item.title,
                    systemImage: item.systemImage,
                    fallbackIcon: item.fallbackIcon
                ) {
                    onSelect(item.action)
                }
            }

            Divider()
                .padding(.vertical, 4)

            MenuActionRowView(title: "Quit", action: onQuit)
        }
        .padding(10)
        .frame(width: 220)
    }
}

private struct MenuActionRowView: View {
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
                    MenuItemIconView(systemName: systemImage, fallback: fallbackIcon)
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

private struct MenuItemIconView: View {
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
