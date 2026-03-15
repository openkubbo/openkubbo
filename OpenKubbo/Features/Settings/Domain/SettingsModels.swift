import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case codexCLI = "API Keys"
    case github = "GitHub"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .appearance:
            return "desktopcomputer"
        case .codexCLI:
            return "chevron.left.forwardslash.chevron.right"
        case .github:
            return "arrow.triangle.branch"
        case .shortcuts:
            return "command"
        }
    }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case automatic = "Automatic"

    var id: String { rawValue }

    init(appTheme: AppTheme) {
        switch appTheme {
        case .light:
            self = .light
        case .dark:
            self = .dark
        case .automatic:
            self = .automatic
        }
    }

    var appTheme: AppTheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .automatic:
            return .automatic
        }
    }
}

struct ShortcutItem: Identifiable, Equatable {
    let id: String
    let name: String
    let keys: [String]

    init(name: String, keys: [String]) {
        self.id = "\(name)-\(keys.joined(separator: "-"))"
        self.name = name
        self.keys = keys
    }
}

struct ShortcutGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [ShortcutItem]

    init(title: String, items: [ShortcutItem]) {
        self.id = title
        self.title = title
        self.items = items
    }
}

extension ShortcutGroup {
    static let defaults: [ShortcutGroup] = [
        ShortcutGroup(
            title: "GENERAL",
            items: [
                ShortcutItem(name: "New Task", keys: ["↩"]),
                ShortcutItem(name: "Settings", keys: ["⌘", ","]),
                ShortcutItem(name: "Search", keys: ["⌘", "F"])
            ]
        ),
        ShortcutGroup(
            title: "WINDOW",
            items: [
                ShortcutItem(name: "Duplicate Window", keys: ["⌘", "D"]),
                ShortcutItem(name: "Close Window", keys: ["⌘", "W"]),
                ShortcutItem(name: "Minimize", keys: ["⌘", "M"])
            ]
        ),
        ShortcutGroup(
            title: "TASKS",
            items: [
                ShortcutItem(name: "Edit Task", keys: ["⌘", "E"]),
                ShortcutItem(name: "Complete Task", keys: ["⌘", "↩"]),
                ShortcutItem(name: "Delete Task", keys: ["⌘", "⌫"])
            ]
        )
    ]
}

struct SettingsSnapshot: Codable, Equatable {
    var selectedTheme: AppTheme

    var launchAtLogin: Bool
    var reopenPreviousWindows: Bool
    var playCompletionSound: Bool
    var hapticsEnabled: Bool
    var appLanguage: String

    var selectedAccentColorIndex: Int

    var selectedModel: String
    var temperature: Double
    var terminalSuggestionsEnabled: Bool
    var automaticErrorAnalysis: Bool
    var syncProfilesEnabled: Bool

    var codexExecutablePath: String? = nil
    var codexExecutableBookmarkData: Data? = nil
    var githubClientID: String? = nil
    var localRepositoriesRootPath: String? = nil
    var localRepositoriesRootBookmarkData: Data? = nil

    static let defaultValue = SettingsSnapshot(
        selectedTheme: .automatic,
        launchAtLogin: false,
        reopenPreviousWindows: true,
        playCompletionSound: true,
        hapticsEnabled: true,
        appLanguage: "English (US)",
        selectedAccentColorIndex: 0,
        selectedModel: "",
        temperature: 0.7,
        terminalSuggestionsEnabled: true,
        automaticErrorAnalysis: false,
        syncProfilesEnabled: true
    )
}
