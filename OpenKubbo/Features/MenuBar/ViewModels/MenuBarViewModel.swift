import Foundation

enum MenuBarAction: Equatable {
    case toggleThemeMode
    case newTask
    case repository
    case terminal
    case agent
    case openSettings
}

struct MenuBarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let fallbackIcon: String
    let action: MenuBarAction
}

final class MenuBarViewModel {
    let items: [MenuBarItem] = [
        MenuBarItem(id: "theme", title: "Theme mode", systemImage: "sun.max", fallbackIcon: "L", action: .toggleThemeMode),
        MenuBarItem(id: "new-task", title: "New Task", systemImage: "text.pad.header.badge.plus", fallbackIcon: "+", action: .newTask),
        MenuBarItem(id: "repository", title: "Repository", systemImage: "selection.pin.in.out", fallbackIcon: "git", action: .repository),
        MenuBarItem(id: "terminal", title: "Terminal", systemImage: "terminal", fallbackIcon: ">_", action: .terminal),
        MenuBarItem(id: "agent", title: "Kubbo Agent", systemImage: "cpu", fallbackIcon: "bot", action: .agent),
        MenuBarItem(id: "settings", title: "Settings", systemImage: "gearshape", fallbackIcon: "S", action: .openSettings)
    ]
}
