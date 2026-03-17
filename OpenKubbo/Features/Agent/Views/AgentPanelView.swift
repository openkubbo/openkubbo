import AppKit
import SwiftUI

struct AgentPanelView: View {
    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    @State private var hostWindow: NSWindow?

    private let panelWidth: CGFloat = 340
    private let panelHeight: CGFloat = 248
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    private var isDarkTheme: Bool {
        themeStore.resolvedColorScheme(systemColorScheme: systemColorScheme) == .dark
    }

    private var accentColor: Color {
        themeStore.accentColor
    }

    private var panelFillColor: Color {
        isDarkTheme ? Color(red: 0.09, green: 0.09, blue: 0.10) : Color(red: 0.97, green: 0.97, blue: 0.98)
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
        isDarkTheme ? .white.opacity(0.60) : .black.opacity(0.48)
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

            VStack(alignment: .leading, spacing: 16) {
                header
                placeholderCard
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
                minimumSize: CGSize(width: 360, height: 272),
                windowIdentifier: "openkubbo.agent.window",
                windowLevel: .floating
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
            }
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Kubbo Agent")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .frame(height: 36, alignment: .center)
                .background(SettingsWindowDragRegion())

            Spacer(minLength: 10)

            Button(action: closeWindow) {
                ZStack {
                    Circle()
                        .fill(isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.08))
                        .frame(width: 42, height: 42)

                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accentColor.opacity(isDarkTheme ? 0.18 : 0.12))
                    )

                Text("Popup ready")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
            }

            Text("This is the first step for Kubbo Agent. Next we can wire real agent actions, prompts, and repository-aware workflows here.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(isDarkTheme ? 0.16 : 0.10))
                .overlay(
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 8, height: 8)
                        Text("Agent entrypoint enabled")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                )
                .frame(height: 42)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: 1)
        )
    }

    private func closeWindow() {
        hostWindow?.close()
    }
}
