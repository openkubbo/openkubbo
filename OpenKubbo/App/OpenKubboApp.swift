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

        Window("Repository", id: "repository") {
            RepositoryPanelView(viewModel: container.repositoryViewModel)
                .environmentObject(container.themeStore)
        }
        .defaultSize(width: 360, height: 728)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Task", id: "task") {
            EphemeralTaskPanelView()
                .environmentObject(container.themeStore)
        }
        .defaultSize(width: 420, height: 546)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        WindowGroup("Task", id: "task-empty") {
            EphemeralTaskPanelView()
                .environmentObject(container.themeStore)
        }
        .defaultSize(width: 420, height: 546)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }

    private func handleMenuSelection(_ action: MenuBarAction) {
        switch action {
        case .openSettings:
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        case .repository:
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "repository")
        case .newTask:
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "task")
        case .terminal:
            openSystemTerminal()
        case .toggleThemeMode:
            container.settingsViewModel.cycleThemeMode()
        case .agent:
            break
        }
    }

    private func openSystemTerminal() {
        let candidatePaths = [
            "/System/Applications/Utilities/Terminal.app",
            "/Applications/Utilities/Terminal.app"
        ]

        let fileManager = FileManager.default
        let terminalURL = candidatePaths
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            .first { fileManager.fileExists(atPath: $0.path) }

        guard let terminalURL else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        NSWorkspace.shared.open(terminalURL)
    }
}

private struct EphemeralTaskPanelView: View {
    @StateObject private var viewModel = TaskViewModel(repository: InMemoryTaskRepository())

    var body: some View {
        TaskPanelView(viewModel: viewModel)
    }
}
