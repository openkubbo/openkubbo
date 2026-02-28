import Foundation
import Testing
@testable import OpenKubbo

@MainActor
struct RepositoryViewModelTests {
    @Test
    func reloadRepositories_loadsRepositories() async {
        let provider = RepositoryDataProviderSpy()
        provider.repositoriesToReturn = [makeRepository(id: "acme/project")]
        let viewModel = makeViewModel(dataProvider: provider)

        await viewModel.reloadRepositories()

        #expect(provider.loadRepositoriesCallCount == 1)
        #expect(viewModel.repositories.map(\.id) == ["acme/project"])
        #expect(viewModel.repositoryLoadErrorMessage == nil)
    }

    @Test
    func loadIssuesIfNeeded_usesCacheAfterFirstLoad() async {
        let provider = RepositoryDataProviderSpy()
        let repo = makeRepository(id: "acme/project", issues: 0)
        provider.repositoriesToReturn = [repo]
        provider.loadIssuesResultsByRepositoryID[repo.id] = [
            [
                makeIssue(repositoryID: repo.id, number: 1),
                makeIssue(repositoryID: repo.id, number: 2)
            ]
        ]

        let viewModel = makeViewModel(dataProvider: provider)
        await viewModel.reloadRepositories()

        await viewModel.loadIssuesIfNeeded(for: repo)
        await viewModel.loadIssuesIfNeeded(for: repo)

        #expect(provider.loadIssuesCallCount(for: repo.id) == 1)
        #expect(viewModel.filteredIssues(for: repo).map(\.number) == [1, 2])
        #expect(viewModel.repositories.first?.issues == 2)
    }

    @Test
    func reloadIssues_ignoresCacheAndLoadsAgain() async {
        let provider = RepositoryDataProviderSpy()
        let repo = makeRepository(id: "acme/project", issues: 0)
        provider.repositoriesToReturn = [repo]
        provider.loadIssuesResultsByRepositoryID[repo.id] = [
            [makeIssue(repositoryID: repo.id, number: 1)],
            [
                makeIssue(repositoryID: repo.id, number: 1),
                makeIssue(repositoryID: repo.id, number: 2),
                makeIssue(repositoryID: repo.id, number: 3)
            ]
        ]

        let viewModel = makeViewModel(dataProvider: provider)
        await viewModel.reloadRepositories()

        await viewModel.loadIssuesIfNeeded(for: repo)
        await viewModel.reloadIssues(for: repo)

        #expect(provider.loadIssuesCallCount(for: repo.id) == 2)
        #expect(viewModel.filteredIssues(for: repo).map(\.number) == [1, 2, 3])
        #expect(viewModel.repositories.first?.issues == 3)
    }

    @Test
    func loadIssuesIfNeeded_ignoresCancellationAndClearsLoadingState() async {
        let provider = RepositoryDataProviderSpy()
        let repo = makeRepository(id: "acme/project", issues: 0)
        provider.repositoriesToReturn = [repo]
        provider.loadIssuesDelayNanoseconds = 10_000_000_000
        provider.loadIssuesResultsByRepositoryID[repo.id] = [[makeIssue(repositoryID: repo.id, number: 1)]]

        let viewModel = makeViewModel(dataProvider: provider)
        await viewModel.reloadRepositories()

        let task = Task {
            await viewModel.loadIssuesIfNeeded(for: repo)
        }

        await waitUntil(timeoutNanoseconds: 1_000_000_000) {
            provider.loadIssuesCallCount(for: repo.id) == 1
        }

        task.cancel()
        await task.value

        #expect(provider.loadIssuesCallCount(for: repo.id) == 1)
        #expect(viewModel.issuesLoadErrorMessage(for: repo) == nil)
        #expect(!viewModel.isLoadingIssues(for: repo))
        #expect(viewModel.filteredIssues(for: repo).isEmpty)
    }
}

private func makeViewModel(dataProvider: RepositoryDataProviding) -> RepositoryViewModel {
    RepositoryViewModel(
        dataProvider: dataProvider,
        localRootProvider: StubLocalRepositoryRootProvider(),
        localResolver: StubLocalRepositoryResolver(),
        localActionService: StubRepositoryLocalActionService(),
        gitHubTokenStore: InMemoryGitHubTokenStore()
    )
}

private func makeRepository(id: String, issues: Int = 0) -> RepoItem {
    RepoItem(
        id: id,
        name: id,
        sshCloneURL: "git@github.com:\(id).git",
        httpsCloneURL: "https://github.com/\(id).git",
        visibility: .openSource,
        issues: issues,
        prs: 0,
        stars: 0,
        branch: "main",
        updatedAgo: "now",
        isPinned: false,
        isWork: false,
        releases: 0,
        ciRuns: 0,
        discussions: 0,
        tags: 0,
        branches: 0,
        contributors: 0,
        openCommits: 0
    )
}

private func makeIssue(repositoryID: String, number: Int) -> RepoIssueItem {
    RepoIssueItem(
        id: "\(repositoryID)-issue-\(number)",
        number: number,
        title: "Issue #\(number)",
        body: "",
        labels: [],
        author: "octocat",
        updatedAgo: "now",
        comments: 0,
        commentItems: [],
        isOpen: true,
        isMine: true
    )
}

private func makePullRequest(repositoryID: String, number: Int = 1) -> RepoPullRequestItem {
    RepoPullRequestItem(
        id: "\(repositoryID)-pr-\(number)",
        number: number,
        title: "PR #\(number)",
        author: "octocat",
        sourceBranch: "feature/test",
        targetBranch: "main",
        updatedAgo: "now",
        comments: 0,
        changedFiles: 1,
        commits: 1,
        additions: 1,
        deletions: 0,
        isOpen: true,
        isMerged: false,
        isMine: true
    )
}

private func makeBranch(repositoryID: String, name: String = "main") -> RepoBranchItem {
    RepoBranchItem(
        id: "\(repositoryID)-branch-\(name)",
        name: name,
        isDefault: name == "main",
        isCurrent: name == "main",
        aheadBy: 0,
        behindBy: 0,
        hasOpenPullRequest: false,
        updatedAgo: "now"
    )
}

private func waitUntil(
    timeoutNanoseconds: UInt64,
    condition: @escaping () -> Bool
) async {
    let start = DispatchTime.now().uptimeNanoseconds

    while !condition() {
        if DispatchTime.now().uptimeNanoseconds - start >= timeoutNanoseconds {
            break
        }
        await Task.yield()
    }
}

private final class RepositoryDataProviderSpy: RepositoryDataProviding {
    var repositoriesToReturn: [RepoItem] = []
    var loadRepositoriesError: Error?
    private(set) var loadRepositoriesCallCount = 0

    var contributionDaysToReturn: [RepoContributionDay] = []
    var loadContributionCalendarError: Error?

    var loadIssuesResultsByRepositoryID: [String: [[RepoIssueItem]]] = [:]
    var loadIssuesDelayNanoseconds: UInt64 = 0
    private var loadIssuesCallCountByRepositoryID: [String: Int] = [:]

    func loadRepositories() async throws -> [RepoItem] {
        loadRepositoriesCallCount += 1
        if let loadRepositoriesError {
            throw loadRepositoriesError
        }
        return repositoriesToReturn
    }

    func loadContributionCalendar() async throws -> [RepoContributionDay] {
        if let loadContributionCalendarError {
            throw loadContributionCalendarError
        }
        return contributionDaysToReturn
    }

    func loadIssues(for repository: RepoItem) async throws -> [RepoIssueItem] {
        loadIssuesCallCountByRepositoryID[repository.id, default: 0] += 1

        if loadIssuesDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: loadIssuesDelayNanoseconds)
        }

        var queue = loadIssuesResultsByRepositoryID[repository.id, default: []]
        guard !queue.isEmpty else {
            return []
        }

        if queue.count > 1 {
            let next = queue.removeFirst()
            loadIssuesResultsByRepositoryID[repository.id] = queue
            return next
        }

        return queue[0]
    }

    func loadIssueComments(
        for issue: RepoIssueItem,
        in repository: RepoItem
    ) async throws -> [RepoIssueCommentItem] {
        _ = issue
        _ = repository
        return []
    }

    func createIssue(
        in repository: RepoItem,
        title: String,
        body: String?
    ) async throws -> RepoIssueItem {
        _ = repository
        _ = title
        _ = body
        return makeIssue(repositoryID: repository.id, number: 1)
    }

    func addIssueComment(
        to issue: RepoIssueItem,
        in repository: RepoItem,
        body: String
    ) async throws -> RepoIssueCommentItem {
        _ = issue
        _ = repository
        _ = body
        return RepoIssueCommentItem(
            id: "comment-1",
            author: "octocat",
            body: "ok",
            updatedAgo: "now"
        )
    }

    func createBranch(
        from issue: RepoIssueItem,
        in repository: RepoItem,
        branchName: String
    ) async throws -> String {
        _ = issue
        _ = repository
        return branchName
    }

    func loadPullRequests(for repository: RepoItem) async throws -> [RepoPullRequestItem] {
        [makePullRequest(repositoryID: repository.id)]
    }

    func loadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repository: RepoItem
    ) async throws -> [RepoPullRequestCommitItem] {
        _ = pullRequest
        _ = repository
        return []
    }

    func createPullRequest(
        in repository: RepoItem,
        title: String,
        body: String?,
        headBranch: String,
        baseBranch: String
    ) async throws -> RepoPullRequestItem {
        _ = title
        _ = body
        _ = headBranch
        _ = baseBranch
        return makePullRequest(repositoryID: repository.id, number: 10)
    }

    func loadCIRuns(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        _ = repository
        return []
    }

    func loadOpenCommits(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        _ = repository
        return []
    }

    func loadTags(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        _ = repository
        return []
    }

    func loadReleases(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        _ = repository
        return []
    }

    func loadDiscussions(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        _ = repository
        return []
    }

    func loadContributors(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        _ = repository
        return []
    }

    func loadInitialMetricCounts(for repository: RepoItem) async throws -> RepoInitialMetricCounts {
        _ = repository
        return RepoInitialMetricCounts(openCommits: 0, tags: 0, releases: 0, discussions: 0, contributors: 0)
    }

    func loadBranches(for repository: RepoItem) async throws -> [RepoBranchItem] {
        [makeBranch(repositoryID: repository.id)]
    }

    func loadIssuesCallCount(for repositoryID: String) -> Int {
        loadIssuesCallCountByRepositoryID[repositoryID, default: 0]
    }
}

private struct StubLocalRepositoryRootProvider: LocalRepositoryRootProviding {
    func currentRootURL() throws -> URL? {
        nil
    }

    func currentRootPath() -> String? {
        nil
    }
}

private struct StubLocalRepositoryResolver: LocalRepositoryResolving {
    func resolve(repo: RepoItem, rootURL: URL?) -> LocalRepositoryMatch {
        _ = repo
        _ = rootURL
        return .rootNotConfigured
    }

    func repositoryDirectoryName(for repo: RepoItem) -> String {
        repo.name
    }
}

private struct StubRepositoryLocalActionService: RepositoryLocalActionServicing {
    func openInFinder(at localURL: URL) throws {
        _ = localURL
    }

    func openInTerminal(at localURL: URL) throws {
        _ = localURL
    }

    func checkoutBranch(named branchName: String, at localURL: URL) throws {
        _ = branchName
        _ = localURL
    }

    func currentBranchName(at localURL: URL) throws -> String? {
        _ = localURL
        return nil
    }

    func listWorktrees(at localURL: URL) throws -> [RepoWorktreeItem] {
        _ = localURL
        return []
    }

    func createWorktree(
        branchName: String,
        at localURL: URL,
        directoryName: String
    ) throws -> URL {
        _ = branchName
        _ = localURL
        return URL(fileURLWithPath: "/tmp/\(directoryName)", isDirectory: true)
    }

    func cloneRepository(
        sshCloneURL: String?,
        httpsCloneURL: String?,
        accessToken: String?,
        into rootURL: URL,
        directoryName: String
    ) async throws -> URL {
        _ = sshCloneURL
        _ = httpsCloneURL
        _ = accessToken
        return rootURL.appendingPathComponent(directoryName, isDirectory: true)
    }
}

private final class InMemoryGitHubTokenStore: GitHubTokenStoring {
    private var storedToken: String?

    func token() -> String? {
        storedToken
    }

    func save(token: String) {
        storedToken = token
    }

    func clear() {
        storedToken = nil
    }
}
