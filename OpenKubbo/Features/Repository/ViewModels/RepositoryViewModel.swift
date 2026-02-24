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
            selectedIssueID = nil
            issueCommentDraft = ""
            selectedPullRequestID = nil
            selectedBranchID = nil
            isPullRequestComposerVisible = false
            pullRequestDraftHeadBranch = nil
        }
    }

    @Published var selectedDetailDestination: RepoDetailDestination?
    @Published var selectedIssuesScope: RepoIssuesScope = .open
    @Published var selectedIssueID: String?
    @Published var issueCommentDraft = ""
    @Published var selectedPullRequestsScope: RepoPullRequestsScope = .open
    @Published var selectedPullRequestID: String?
    @Published var selectedBranchID: String?
    @Published var isPullRequestComposerVisible = false
    @Published var pullRequestDraftHeadBranch: String?

    private let dataProvider: RepositoryDataProviding
    private let localRootProvider: LocalRepositoryRootProviding
    private let localResolver: LocalRepositoryResolving
    private let localActionService: RepositoryLocalActionServicing
    private let gitHubTokenStore: GitHubTokenStoring
    private var hasUserCustomizedPins = false
    private var issueCommentItemsByIssueID: [String: [RepoIssueCommentItem]] = [:]

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

    var canSubmitIssueComment: Bool {
        !trimmedIssueCommentDraft.isEmpty
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
        selectedIssueID = nil
        issueCommentDraft = ""
        selectedPullRequestID = nil
        selectedBranchID = nil
        isPullRequestComposerVisible = false
        pullRequestDraftHeadBranch = nil
        selectedRepoID = nil
    }

    func openDetailPanel(_ destination: RepoDetailDestination) {
        if destination == .issues {
            selectedIssuesScope = .open
            selectedIssueID = nil
            issueCommentDraft = ""
        } else {
            issueCommentDraft = ""
        }
        if destination == .pullRequests {
            selectedPullRequestsScope = .open
            isPullRequestComposerVisible = false
        } else {
            isPullRequestComposerVisible = false
        }
        selectedPullRequestID = nil
        if destination != .branches {
            selectedBranchID = nil
        }
        selectedDetailDestination = destination
    }

    func closeDetailPanel() {
        selectedDetailDestination = nil
        selectedIssueID = nil
        issueCommentDraft = ""
        selectedPullRequestID = nil
        selectedBranchID = nil
        isPullRequestComposerVisible = false
        pullRequestDraftHeadBranch = nil
    }

    func selectIssuesScope(_ scope: RepoIssuesScope) {
        selectedIssuesScope = scope
        selectedIssueID = nil
        issueCommentDraft = ""
    }

    func filteredIssues(for repo: RepoItem) -> [RepoIssueItem] {
        let issues = dataProvider.loadIssues(for: repo).map(resolveIssueComments)

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

    func selectIssue(_ issue: RepoIssueItem) {
        selectedIssueID = issue.id
        issueCommentDraft = ""
    }

    func closeIssueDetails() {
        selectedIssueID = nil
        issueCommentDraft = ""
    }

    func selectedIssue(for repo: RepoItem) -> RepoIssueItem? {
        guard let selectedIssueID else { return nil }
        return filteredIssues(for: repo).first(where: { $0.id == selectedIssueID })
    }

    func addIssueComment(to issue: RepoIssueItem) {
        let draft = trimmedIssueCommentDraft
        guard !draft.isEmpty else { return }

        let currentItems = issueCommentItemsByIssueID[issue.id] ?? issue.commentItems
        let newComment = RepoIssueCommentItem(
            id: "\(issue.id)-comment-\(UUID().uuidString)",
            author: "you",
            body: draft,
            updatedAgo: "just now"
        )

        issueCommentItemsByIssueID[issue.id] = currentItems + [newComment]
        issueCommentDraft = ""
    }

    func selectPullRequestsScope(_ scope: RepoPullRequestsScope) {
        selectedPullRequestsScope = scope
        selectedPullRequestID = nil
        isPullRequestComposerVisible = false
    }

    func filteredPullRequests(for repo: RepoItem) -> [RepoPullRequestItem] {
        let pullRequests = dataProvider.loadPullRequests(for: repo)

        switch selectedPullRequestsScope {
        case .all:
            return pullRequests
        case .mine:
            return pullRequests.filter(\.isMine)
        case .open:
            return pullRequests.filter(\.isOpen)
        case .merged:
            return pullRequests.filter(\.isMerged)
        }
    }

    func selectPullRequest(_ pullRequest: RepoPullRequestItem) {
        isPullRequestComposerVisible = false
        selectedPullRequestID = pullRequest.id
    }

    func closePullRequestDetails() {
        selectedPullRequestID = nil
    }

    func selectedPullRequest(for repo: RepoItem) -> RepoPullRequestItem? {
        guard let selectedPullRequestID else { return nil }
        return filteredPullRequests(for: repo).first(where: { $0.id == selectedPullRequestID })
    }

    func pullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repo: RepoItem
    ) -> [RepoPullRequestCommitItem] {
        dataProvider.loadPullRequestCommits(for: pullRequest, in: repo)
    }

    func branches(for repo: RepoItem) -> [RepoBranchItem] {
        dataProvider.loadBranches(for: repo)
    }

    func selectedBranch(for repo: RepoItem) -> RepoBranchItem? {
        guard let selectedBranchID else { return nil }
        return branches(for: repo).first(where: { $0.id == selectedBranchID })
    }

    func selectBranch(_ branch: RepoBranchItem) {
        selectedBranchID = branch.id
    }

    func closeBranchDetails() {
        selectedBranchID = nil
    }

    func openPullRequestComposer(
        in repo: RepoItem,
        preferredHeadBranch: String? = nil
    ) {
        selectedDetailDestination = .pullRequests
        selectedPullRequestID = nil
        selectedBranchID = nil
        isPullRequestComposerVisible = true
        if let preferredHeadBranch, !preferredHeadBranch.isEmpty {
            pullRequestDraftHeadBranch = preferredHeadBranch
        }
        if pullRequestDraftHeadBranch == nil {
            pullRequestDraftHeadBranch = eligiblePullRequestBranches(for: repo).first?.name
        }
    }

    func closePullRequestComposer() {
        isPullRequestComposerVisible = false
    }

    func eligiblePullRequestBranches(for repo: RepoItem) -> [RepoBranchItem] {
        branches(for: repo).filter { branch in
            branch.canOpenPullRequest(baseBranch: repo.branch)
        }
    }

    func selectPullRequestDraftHeadBranch(_ branch: RepoBranchItem) {
        pullRequestDraftHeadBranch = branch.name
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

    private var trimmedIssueCommentDraft: String {
        issueCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveIssueComments(_ issue: RepoIssueItem) -> RepoIssueItem {
        guard let overriddenComments = issueCommentItemsByIssueID[issue.id] else {
            return issue
        }

        let unresolvedCommentsCount = max(0, issue.comments - issue.commentItems.count)
        let resolvedCount = overriddenComments.count + unresolvedCommentsCount

        return RepoIssueItem(
            id: issue.id,
            number: issue.number,
            title: issue.title,
            body: issue.body,
            labels: issue.labels,
            author: issue.author,
            updatedAgo: issue.updatedAgo,
            comments: resolvedCount,
            commentItems: overriddenComments,
            isOpen: issue.isOpen,
            isMine: issue.isMine
        )
    }
}
