import Foundation

enum LocalRepositoryRootError: LocalizedError {
    case invalidBookmark

    var errorDescription: String? {
        switch self {
        case .invalidBookmark:
            return "Unable to access the configured local repositories folder."
        }
    }
}

protocol LocalRepositoryRootProviding {
    func currentRootURL() throws -> URL?
    func currentRootPath() -> String?
}

struct SettingsLocalRepositoryRootProvider: LocalRepositoryRootProviding {
    private let settingsRepository: SettingsRepository

    init(settingsRepository: SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    func currentRootURL() throws -> URL? {
        let snapshot = settingsRepository.load()
        guard let bookmarkData = snapshot.localRepositoriesRootBookmarkData else {
            return nil
        }

        var isStale = false

        do {
            let rootURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                var refreshedSnapshot = snapshot
                refreshedSnapshot.localRepositoriesRootPath = rootURL.path
                refreshedSnapshot.localRepositoriesRootBookmarkData = try rootURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                settingsRepository.save(refreshedSnapshot)
            }

            return rootURL
        } catch {
            throw LocalRepositoryRootError.invalidBookmark
        }
    }

    func currentRootPath() -> String? {
        settingsRepository.load().localRepositoriesRootPath
    }
}
