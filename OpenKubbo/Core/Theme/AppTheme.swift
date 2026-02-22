import Foundation

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case light
    case dark
    case automatic

    var id: String { rawValue }
}
