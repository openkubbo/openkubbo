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

enum TaskGenerationProvider: String, Codable, CaseIterable, Identifiable {
    case openAI
    case google

    var id: String { rawValue }
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

    var taskGenerationProvider: TaskGenerationProvider = .openAI
    var selectedModel: String
    var geminiSelectedModel: String = ""
    var temperature: Double
    var terminalSuggestionsEnabled: Bool
    var automaticErrorAnalysis: Bool
    var syncProfilesEnabled: Bool

    var codexExecutablePath: String? = nil
    var codexExecutableBookmarkData: Data? = nil
    var geminiExecutablePath: String? = nil
    var geminiExecutableBookmarkData: Data? = nil
    var nodeExecutablePath: String? = nil
    var nodeExecutableBookmarkData: Data? = nil
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
        taskGenerationProvider: .openAI,
        selectedModel: "",
        geminiSelectedModel: "",
        temperature: 0.7,
        terminalSuggestionsEnabled: true,
        automaticErrorAnalysis: false,
        syncProfilesEnabled: true
    )
}

extension SettingsSnapshot {
    private enum CodingKeys: String, CodingKey {
        case selectedTheme
        case launchAtLogin
        case reopenPreviousWindows
        case playCompletionSound
        case hapticsEnabled
        case appLanguage
        case selectedAccentColorIndex
        case taskGenerationProvider
        case selectedModel
        case geminiSelectedModel
        case temperature
        case terminalSuggestionsEnabled
        case automaticErrorAnalysis
        case syncProfilesEnabled
        case codexExecutablePath
        case codexExecutableBookmarkData
        case geminiExecutablePath
        case geminiExecutableBookmarkData
        case nodeExecutablePath
        case nodeExecutableBookmarkData
        case githubClientID
        case localRepositoriesRootPath
        case localRepositoriesRootBookmarkData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaultValue

        selectedTheme = try container.decodeIfPresent(AppTheme.self, forKey: .selectedTheme) ?? defaults.selectedTheme
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        reopenPreviousWindows = try container.decodeIfPresent(Bool.self, forKey: .reopenPreviousWindows) ?? defaults.reopenPreviousWindows
        playCompletionSound = try container.decodeIfPresent(Bool.self, forKey: .playCompletionSound) ?? defaults.playCompletionSound
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        appLanguage = try container.decodeIfPresent(String.self, forKey: .appLanguage) ?? defaults.appLanguage
        selectedAccentColorIndex = try container.decodeIfPresent(Int.self, forKey: .selectedAccentColorIndex) ?? defaults.selectedAccentColorIndex
        taskGenerationProvider = try container.decodeIfPresent(TaskGenerationProvider.self, forKey: .taskGenerationProvider) ?? defaults.taskGenerationProvider
        selectedModel = try container.decodeIfPresent(String.self, forKey: .selectedModel) ?? defaults.selectedModel
        geminiSelectedModel = try container.decodeIfPresent(String.self, forKey: .geminiSelectedModel) ?? defaults.geminiSelectedModel
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? defaults.temperature
        terminalSuggestionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .terminalSuggestionsEnabled) ?? defaults.terminalSuggestionsEnabled
        automaticErrorAnalysis = try container.decodeIfPresent(Bool.self, forKey: .automaticErrorAnalysis) ?? defaults.automaticErrorAnalysis
        syncProfilesEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncProfilesEnabled) ?? defaults.syncProfilesEnabled
        codexExecutablePath = try container.decodeIfPresent(String.self, forKey: .codexExecutablePath)
        codexExecutableBookmarkData = try container.decodeIfPresent(Data.self, forKey: .codexExecutableBookmarkData)
        geminiExecutablePath = try container.decodeIfPresent(String.self, forKey: .geminiExecutablePath)
        geminiExecutableBookmarkData = try container.decodeIfPresent(Data.self, forKey: .geminiExecutableBookmarkData)
        nodeExecutablePath = try container.decodeIfPresent(String.self, forKey: .nodeExecutablePath)
        nodeExecutableBookmarkData = try container.decodeIfPresent(Data.self, forKey: .nodeExecutableBookmarkData)
        githubClientID = try container.decodeIfPresent(String.self, forKey: .githubClientID)
        localRepositoriesRootPath = try container.decodeIfPresent(String.self, forKey: .localRepositoriesRootPath)
        localRepositoriesRootBookmarkData = try container.decodeIfPresent(Data.self, forKey: .localRepositoriesRootBookmarkData)
    }
}
