import Foundation

enum LocalRepositoryMatch {
    case rootNotConfigured
    case matched(localURL: URL)
    case missing(expectedURL: URL)
}

protocol LocalRepositoryResolving {
    func resolve(repo: RepoItem, rootURL: URL?) -> LocalRepositoryMatch
    func repositoryDirectoryName(for repo: RepoItem) -> String
}

struct LocalRepositoryResolver: LocalRepositoryResolving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolve(repo: RepoItem, rootURL: URL?) -> LocalRepositoryMatch {
        guard let rootURL else {
            return .rootNotConfigured
        }

        let directoryName = repositoryDirectoryName(for: repo)
        let expectedURL = rootURL.appendingPathComponent(directoryName, isDirectory: true)
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: expectedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return .matched(localURL: expectedURL)
        }

        return .missing(expectedURL: expectedURL)
    }

    func repositoryDirectoryName(for repo: RepoItem) -> String {
        let candidate = repo.name.split(separator: "/").last.map(String.init) ?? repo.name
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? repo.id : trimmed
    }
}
