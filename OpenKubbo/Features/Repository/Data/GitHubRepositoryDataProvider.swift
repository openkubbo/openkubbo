import Foundation

enum RepositoryDataError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Connect your GitHub account first to load repositories."
        }
    }
}

struct GitHubRepositoryDataProvider: RepositoryDataProviding {
    private let gitHubAPIService: GitHubAPIServicing
    private let gitHubTokenStore: GitHubTokenStoring
    private let fallbackIssuesProvider: MockRepositoryDataProvider

    init(
        gitHubAPIService: GitHubAPIServicing,
        gitHubTokenStore: GitHubTokenStoring,
        fallbackIssuesProvider: MockRepositoryDataProvider = MockRepositoryDataProvider()
    ) {
        self.gitHubAPIService = gitHubAPIService
        self.gitHubTokenStore = gitHubTokenStore
        self.fallbackIssuesProvider = fallbackIssuesProvider
    }

    func loadRepositories() async throws -> [RepoItem] {
        guard let token = gitHubTokenStore.token(),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryDataError.notAuthenticated
        }

        let repositories = try await gitHubAPIService.fetchRepositories(accessToken: token)

        return repositories.enumerated().map { index, repository in
            mapToRepoItem(repository, index: index)
        }
    }

    func loadIssues(for repository: RepoItem) -> [RepoIssueItem] {
        fallbackIssuesProvider.loadIssues(for: repository)
    }

    private func mapToRepoItem(_ repository: GitHubRepository, index: Int) -> RepoItem {
        let seed = seededValue("\(repository.fullName)-seed")
        let visibility: RepoVisibility = repository.isPrivate ? .private : .openSource
        let prs = min(12, max(0, repository.openIssuesCount / 3 + Int(seed % 2)))

        return RepoItem(
            id: repository.fullName,
            name: repository.fullName,
            sshCloneURL: repository.sshCloneURL,
            httpsCloneURL: repository.httpsCloneURL,
            visibility: visibility,
            issues: max(0, repository.openIssuesCount),
            prs: prs,
            stars: max(0, repository.stargazersCount),
            branch: repository.defaultBranch,
            updatedAgo: relativeTime(from: repository.updatedAt),
            isPinned: index < 5,
            isWork: repository.isPrivate,
            releases: metric("\(repository.fullName)-releases", min: 0, max: 28),
            ciRuns: metric("\(repository.fullName)-ci", min: 8, max: 3200),
            discussions: metric("\(repository.fullName)-discussions", min: 0, max: 22),
            tags: metric("\(repository.fullName)-tags", min: 0, max: 34),
            branches: metric("\(repository.fullName)-branches", min: 1, max: 12),
            contributors: metric("\(repository.fullName)-contributors", min: 1, max: 14),
            openCommits: metric("\(repository.fullName)-commits", min: 1, max: 90)
        )
    }

    private func metric(_ key: String, min: Int, max: Int) -> Int {
        guard max >= min else { return min }
        let range = UInt64(max - min + 1)
        return min + Int(seededValue(key) % range)
    }

    private func seededValue(_ key: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func relativeTime(from date: Date?) -> String {
        guard let date else { return "just now" }

        let elapsed = max(0, Int(Date().timeIntervalSince(date)))
        if elapsed < 60 {
            return "just now"
        }

        let minutes = elapsed / 60
        if minutes < 60 {
            return "\(minutes) min. ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) hr. ago"
        }

        let days = hours / 24
        if days < 30 {
            return "\(days) day" + (days == 1 ? " ago" : "s ago")
        }

        let months = days / 30
        if months < 12 {
            return "\(months) mo. ago"
        }

        let years = months / 12
        return "\(years) yr. ago"
    }
}
