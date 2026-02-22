import AppKit
import SwiftUI

@main
struct OpenKubboApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraView(viewModel: container.menuBarViewModel) { action in
                handleMenuSelection(action)
            } onQuit: {
                NSApplication.shared.terminate(nil)
            }
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
            SettingsView(viewModel: container.settingsViewModel)
                .environmentObject(container.themeStore)
        }
        .defaultSize(width: 720, height: 450)
        .windowResizability(.automatic)
        .windowStyle(.hiddenTitleBar)
    }

    private func handleMenuSelection(_ action: MenuBarAction) {
        switch action {
        case .openSettings:
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        case .toggleThemeMode:
            container.settingsViewModel.cycleThemeMode()
        case .newTask, .repository, .terminal, .agent:
            break
        }
    }
}
