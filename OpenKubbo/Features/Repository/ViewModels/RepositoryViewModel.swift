import Combine
import Foundation

@MainActor
final class RepositoryViewModel: ObservableObject {
    @Published private(set) var repositories: [RepoItem] = []
    @Published private(set) var repositoryLoadErrorMessage: String?

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

    init(dataProvider: RepositoryDataProviding = MockRepositoryDataProvider()) {
        self.dataProvider = dataProvider
        reloadRepositories()
    }

    var filteredRepos: [RepoItem] {
        switch selectedFilter {
        case .all:
            return repositories
        case .pinned:
            return repositories.filter { $0.isPinned }
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

    func reloadRepositories() {
        repositories = dataProvider.loadRepositories()
        repositoryLoadErrorMessage = nil
        synchronizeSelectedRepo()
    }

    func selectFilter(_ filter: RepoFilter) {
        selectedFilter = filter
    }

    func selectRepository(_ repo: RepoItem) {
        selectedRepoID = repo.id
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

    private func synchronizeSelectedRepo() {
        guard let selectedRepoID else { return }

        if !filteredRepos.contains(where: { $0.id == selectedRepoID }) {
            closeRepositorySelection()
        }
    }
}
