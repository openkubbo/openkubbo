import Combine
import Foundation

enum RepositoryLocalActionKind {
    case finder
    case terminal
}

enum RepositoryLocalActionResult {
    case opened
    case cloned(localPath: String)
    case rootNotConfigured
    case cloneRequired(expectedPath: String)
    case failed(String)
}

@MainActor
final class RepositoryViewModel: ObservableObject {
    @Published private(set) var repositories: [RepoItem] = []
    @Published private(set) var isLoadingRepositories = false
    @Published private(set) var repositoryLoadErrorMessage: String?
    @Published private(set) var pinnedRepositoryIDs: Set<String> = []

    @Published var selectedFilter: RepoFilter = .all {
        didSet {
            synchronizeSelectedRepo()
        }
    }

    @Published var selectedRepoID: String? {
        didSet {
            selectedDetailDestination = nil
        }
    }

    @Published var selectedDetailDestination: RepoDetailDestination?
    @Published var selectedIssuesScope: RepoIssuesScope = .open

    private let dataProvider: RepositoryDataProviding
    private let localRootProvider: LocalRepositoryRootProviding
    private let localResolver: LocalRepositoryResolving
    private let localActionService: RepositoryLocalActionServicing
    private let gitHubTokenStore: GitHubTokenStoring
    private var hasUserCustomizedPins = false

    init(
        dataProvider: RepositoryDataProviding,
        localRootProvider: LocalRepositoryRootProviding,
        localResolver: LocalRepositoryResolving,
        localActionService: RepositoryLocalActionServicing,
        gitHubTokenStore: GitHubTokenStoring
    ) {
        self.dataProvider = dataProvider
        self.localRootProvider = localRootProvider
        self.localResolver = localResolver
        self.localActionService = localActionService
        self.gitHubTokenStore = gitHubTokenStore
    }

    var filteredRepos: [RepoItem] {
        switch selectedFilter {
        case .all:
            return repositories
        case .pinned:
            return repositories.filter { pinnedRepositoryIDs.contains($0.id) }
        case .work:
            return repositories.filter { $0.isWork }
        }
    }

    var selectedRepo: RepoItem? {
        guard let selectedRepoID else { return nil }
        return filteredRepos.first { $0.id == selectedRepoID }
    }

    var isDetailsVisible: Bool {
        selectedRepo != nil
    }

    func reloadRepositories() async {
        guard !isLoadingRepositories else { return }

        isLoadingRepositories = true
        defer { isLoadingRepositories = false }

        do {
            repositories = try await dataProvider.loadRepositories()
            applyPinnedState(for: repositories)
            repositoryLoadErrorMessage = nil
            synchronizeSelectedRepo()

            if repositories.isEmpty {
                closeRepositorySelection()
            }
        } catch {
            repositories = []
            closeRepositorySelection()
            repositoryLoadErrorMessage = repositoryErrorDescription(error)
        }
    }

    func selectFilter(_ filter: RepoFilter) {
        selectedFilter = filter
    }

    func selectRepository(_ repo: RepoItem) {
        selectedRepoID = repo.id
    }

    func repository(withID repositoryID: String) -> RepoItem? {
        repositories.first(where: { $0.id == repositoryID })
    }

    func isRepoPinned(_ repo: RepoItem) -> Bool {
        pinnedRepositoryIDs.contains(repo.id)
    }

    func togglePinned(_ repo: RepoItem) {
        hasUserCustomizedPins = true

        if pinnedRepositoryIDs.contains(repo.id) {
            pinnedRepositoryIDs.remove(repo.id)
        } else {
            pinnedRepositoryIDs.insert(repo.id)
        }

        synchronizeSelectedRepo()
    }

    func closeRepositorySelection() {
        selectedDetailDestination = nil
        selectedRepoID = nil
    }

    func openDetailPanel(_ destination: RepoDetailDestination) {
        if destination == .issues {
            selectedIssuesScope = .open
        }
        selectedDetailDestination = destination
    }

    func closeDetailPanel() {
        selectedDetailDestination = nil
    }

    func selectIssuesScope(_ scope: RepoIssuesScope) {
        selectedIssuesScope = scope
    }

    func filteredIssues(for repo: RepoItem) -> [RepoIssueItem] {
        let issues = dataProvider.loadIssues(for: repo)

        switch selectedIssuesScope {
        case .all:
            return issues
        case .mine:
            return issues.filter(\.isMine)
        case .open:
            return issues.filter(\.isOpen)
        case .closed:
            return issues.filter { !$0.isOpen }
        }
    }

    func openInFinder(for repo: RepoItem) -> RepositoryLocalActionResult {
        performLocalAction(.finder, for: repo)
    }

    func openInTerminal(for repo: RepoItem) -> RepositoryLocalActionResult {
        performLocalAction(.terminal, for: repo)
    }

    func cloneLocalRepository(for repo: RepoItem) async -> RepositoryLocalActionResult {
        do {
            guard let rootURL = try localRootProvider.currentRootURL() else {
                return .rootNotConfigured
            }

            let localMatch = localResolver.resolve(repo: repo, rootURL: rootURL)
            switch localMatch {
            case .rootNotConfigured:
                return .rootNotConfigured
            case .matched(let localURL):
                return .cloned(localPath: localURL.path)
            case .missing:
                let directoryName = localResolver.repositoryDirectoryName(for: repo)
                let destinationURL = try await localActionService.cloneRepository(
                    sshCloneURL: repo.sshCloneURL,
                    httpsCloneURL: repo.httpsCloneURL,
                    accessToken: gitHubTokenStore.token(),
                    into: rootURL,
                    directoryName: directoryName
                )

                return .cloned(localPath: destinationURL.path)
            }
        } catch {
            return .failed(repositoryErrorDescription(error))
        }
    }

    private func performLocalAction(_ action: RepositoryLocalActionKind, for repo: RepoItem) -> RepositoryLocalActionResult {
        do {
            let rootURL = try localRootProvider.currentRootURL()
            let localMatch = localResolver.resolve(repo: repo, rootURL: rootURL)

            switch localMatch {
            case .rootNotConfigured:
                return .rootNotConfigured
            case .missing(let expectedURL):
                return .cloneRequired(expectedPath: expectedURL.path)
            case .matched(let localURL):
                try withRootAccess(rootURL: rootURL) {
                    switch action {
                    case .finder:
                        try localActionService.openInFinder(at: localURL)
                    case .terminal:
                        try localActionService.openInTerminal(at: localURL)
                    }
                }
                return .opened
            }
        } catch {
            return .failed(repositoryErrorDescription(error))
        }
    }

    private func withRootAccess<T>(rootURL: URL?, operation: () throws -> T) throws -> T {
        guard let rootURL else {
            return try operation()
        }

        let hasSecurityAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        return try operation()
    }

    private func synchronizeSelectedRepo() {
        guard let selectedRepoID else { return }

        if !filteredRepos.contains(where: { $0.id == selectedRepoID }) {
            closeRepositorySelection()
        }
    }

    private func applyPinnedState(for repositories: [RepoItem]) {
        let validIDs = Set(repositories.map(\.id))

        if hasUserCustomizedPins {
            pinnedRepositoryIDs = pinnedRepositoryIDs.intersection(validIDs)
            return
        }

        let retainedDefaultPins = pinnedRepositoryIDs.intersection(validIDs)
        if !retainedDefaultPins.isEmpty {
            pinnedRepositoryIDs = retainedDefaultPins
            return
        }

        pinnedRepositoryIDs = Set(repositories.filter(\.isPinned).map(\.id))
    }

    private func repositoryErrorDescription(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }

        return error.localizedDescription
    }
}
