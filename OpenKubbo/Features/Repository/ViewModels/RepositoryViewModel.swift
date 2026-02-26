import Combine
import Foundation

enum RepositoryLocalActionKind {
    case finder
    case terminal
    case checkout(branchName: String)
    case terminalOnBranch(branchName: String)
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
    @Published private(set) var contributionCountsByDateKey: [String: Int] = [:]
    @Published private(set) var isLoadingRepositories = false
    @Published private(set) var isLoadingContributionCalendar = false
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
            isIssueComposerVisible = false
            issueDraftTitle = ""
            issueDraftBody = ""
            issueCommentDraft = ""
            issueBranchDraftName = ""
            isIssueBranchComposerVisible = false
            selectedPullRequestID = nil
            isPullRequestCreating = false
            pullRequestActionErrorMessage = nil
            pullRequestActionStatusMessage = nil
            pullRequestDraftTitle = ""
            pullRequestDraftBody = ""
            selectedBranchID = nil
            selectedDestinationInfoItemID = nil
            isPullRequestComposerVisible = false
            pullRequestDraftHeadBranch = nil
            issueActionErrorMessage = nil
            issueActionStatusMessage = nil
        }
    }

    @Published var selectedDetailDestination: RepoDetailDestination?
    @Published var selectedIssuesScope: RepoIssuesScope = .open
    @Published var selectedIssueID: String?
    @Published var isIssueComposerVisible = false
    @Published private(set) var isIssueCreating = false
    @Published private(set) var isIssueCommentSubmitting = false
    @Published private(set) var isIssueBranchCreating = false
    @Published private(set) var isIssueCommentsLoading = false
    @Published private(set) var issueRefreshingID: String?
    @Published private(set) var issueActionErrorMessage: String?
    @Published private(set) var issueActionStatusMessage: String?
    @Published var issueDraftTitle = ""
    @Published var issueDraftBody = ""
    @Published var issueCommentDraft = ""
    @Published var issueBranchDraftName = ""
    @Published var isIssueBranchComposerVisible = false
    @Published var selectedPullRequestsScope: RepoPullRequestsScope = .open
    @Published var selectedPullRequestID: String?
    @Published private(set) var isPullRequestCreating = false
    @Published private(set) var pullRequestActionErrorMessage: String?
    @Published private(set) var pullRequestActionStatusMessage: String?
    @Published var pullRequestDraftTitle = ""
    @Published var pullRequestDraftBody = ""
    @Published var selectedBranchID: String?
    @Published var selectedDestinationInfoItemID: String?
    @Published var isPullRequestComposerVisible = false
    @Published var pullRequestDraftHeadBranch: String?

    private let dataProvider: RepositoryDataProviding
    private let localRootProvider: LocalRepositoryRootProviding
    private let localResolver: LocalRepositoryResolving
    private let localActionService: RepositoryLocalActionServicing
    private let gitHubTokenStore: GitHubTokenStoring
    private var hasUserCustomizedPins = false
    private var optimisticBranchNamesByRepositoryID: [String: Set<String>] = [:]
    @Published private(set) var loadedIssuesByRepositoryID: [String: [RepoIssueItem]] = [:]
    @Published private(set) var issuesLoadingRepositoryIDs: Set<String> = []
    @Published private(set) var issuesLoadErrorMessageByRepositoryID: [String: String] = [:]
    @Published private(set) var loadedBranchesByRepositoryID: [String: [RepoBranchItem]] = [:]
    @Published private(set) var branchesLoadingRepositoryIDs: Set<String> = []
    @Published private(set) var branchesLoadErrorMessageByRepositoryID: [String: String] = [:]
    @Published private(set) var loadedPullRequestsByRepositoryID: [String: [RepoPullRequestItem]] = [:]
    @Published private(set) var pullRequestsLoadingRepositoryIDs: Set<String> = []
    @Published private(set) var pullRequestsLoadErrorMessageByRepositoryID: [String: String] = [:]
    @Published private(set) var loadedPullRequestCommitsByPullRequestID: [String: [RepoPullRequestCommitItem]] = [:]
    @Published private(set) var pullRequestCommitsLoadingPullRequestIDs: Set<String> = []
    @Published private(set) var pullRequestCommitsLoadErrorMessageByPullRequestID: [String: String] = [:]
    @Published private(set) var loadedCIRunsByRepositoryID: [String: [RepoDestinationInfoItem]] = [:]
    @Published private(set) var ciRunsLoadingRepositoryIDs: Set<String> = []
    @Published private(set) var ciRunsLoadErrorMessageByRepositoryID: [String: String] = [:]
    @Published private(set) var issueBranchNamesByIssueKey: [String: [String]] = [:]
    @Published private(set) var localCurrentBranchByRepositoryID: [String: String] = [:]

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

    var canCreateIssue: Bool {
        !trimmedIssueDraftTitle.isEmpty
    }

    var canCreatePullRequest: Bool {
        !trimmedPullRequestDraftTitle.isEmpty && pullRequestDraftHeadBranch != nil
    }

    var totalContributionsLast12Months: Int {
        contributionCountsByDateKey.values.reduce(0, +)
    }

    var isPrimaryPanelRefreshing: Bool {
        isLoadingRepositories || isLoadingContributionCalendar
    }

    func reloadPanelData() async {
        await reloadRepositories()
        await reloadContributionCalendar()
    }

    func reloadRepositories() async {
        guard !isLoadingRepositories else { return }

        isLoadingRepositories = true
        defer { isLoadingRepositories = false }

        do {
            repositories = try await dataProvider.loadRepositories()
            applyPinnedState(for: repositories)
            repositoryLoadErrorMessage = nil
            pruneIssuesCache(for: repositories)
            synchronizeSelectedRepo()

            if repositories.isEmpty {
                closeRepositorySelection()
            }
        } catch {
            repositories = []
            loadedIssuesByRepositoryID = [:]
            issuesLoadingRepositoryIDs = []
            issuesLoadErrorMessageByRepositoryID = [:]
            loadedBranchesByRepositoryID = [:]
            branchesLoadingRepositoryIDs = []
            branchesLoadErrorMessageByRepositoryID = [:]
            loadedPullRequestsByRepositoryID = [:]
            pullRequestsLoadingRepositoryIDs = []
            pullRequestsLoadErrorMessageByRepositoryID = [:]
            loadedPullRequestCommitsByPullRequestID = [:]
            pullRequestCommitsLoadingPullRequestIDs = []
            pullRequestCommitsLoadErrorMessageByPullRequestID = [:]
            loadedCIRunsByRepositoryID = [:]
            ciRunsLoadingRepositoryIDs = []
            ciRunsLoadErrorMessageByRepositoryID = [:]
            issueBranchNamesByIssueKey = [:]
            optimisticBranchNamesByRepositoryID = [:]
            localCurrentBranchByRepositoryID = [:]
            closeRepositorySelection()
            repositoryLoadErrorMessage = repositoryErrorDescription(error)
        }
    }

    func reloadContributionCalendar() async {
        guard !isLoadingContributionCalendar else { return }

        isLoadingContributionCalendar = true
        defer { isLoadingContributionCalendar = false }

        do {
            let contributionDays = try await dataProvider.loadContributionCalendar()
            var mapped: [String: Int] = [:]
            mapped.reserveCapacity(contributionDays.count)

            for day in contributionDays {
                mapped[day.dateKey] = max(0, day.count)
            }

            contributionCountsByDateKey = mapped
        } catch {
            contributionCountsByDateKey = [:]
        }
    }

    func selectFilter(_ filter: RepoFilter) {
        selectedFilter = filter
    }

    func selectRepository(_ repo: RepoItem) {
        selectedRepoID = repo.id
        refreshLocalCurrentBranch(for: repo)
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
        isIssueComposerVisible = false
        issueDraftTitle = ""
        issueDraftBody = ""
        issueCommentDraft = ""
        issueBranchDraftName = ""
        isIssueBranchComposerVisible = false
        isIssueCommentsLoading = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
        selectedPullRequestID = nil
        isPullRequestCreating = false
        pullRequestActionErrorMessage = nil
        pullRequestActionStatusMessage = nil
        pullRequestDraftTitle = ""
        pullRequestDraftBody = ""
        selectedBranchID = nil
        selectedDestinationInfoItemID = nil
        isPullRequestComposerVisible = false
        pullRequestDraftHeadBranch = nil
        selectedRepoID = nil
    }

    func openDetailPanel(_ destination: RepoDetailDestination) {
        if destination == .issues {
            selectedIssuesScope = .open
            selectedIssueID = nil
            isIssueComposerVisible = false
            issueDraftTitle = ""
            issueDraftBody = ""
            issueCommentDraft = ""
            issueBranchDraftName = ""
            isIssueBranchComposerVisible = false
            issueActionErrorMessage = nil
            issueActionStatusMessage = nil
        } else {
            isIssueComposerVisible = false
            issueDraftTitle = ""
            issueDraftBody = ""
            issueCommentDraft = ""
            issueBranchDraftName = ""
            isIssueBranchComposerVisible = false
        }
        if destination == .pullRequests {
            selectedPullRequestsScope = .open
            isPullRequestComposerVisible = false
            isPullRequestCreating = false
            pullRequestActionErrorMessage = nil
            pullRequestActionStatusMessage = nil
            pullRequestDraftTitle = ""
            pullRequestDraftBody = ""
        } else {
            isPullRequestComposerVisible = false
            isPullRequestCreating = false
            pullRequestActionErrorMessage = nil
            pullRequestActionStatusMessage = nil
            pullRequestDraftTitle = ""
            pullRequestDraftBody = ""
        }
        selectedPullRequestID = nil
        if destination != .branches {
            selectedBranchID = nil
        }
        selectedDestinationInfoItemID = nil
        selectedDetailDestination = destination

        if destination == .issues, let repo = selectedRepo {
            Task { [weak self] in
                await self?.loadBranchesIfNeeded(for: repo)
                await self?.loadIssuesIfNeeded(for: repo)
            }
        } else if destination == .pullRequests, let repo = selectedRepo {
            Task { [weak self] in
                await self?.loadBranchesIfNeeded(for: repo)
                await self?.loadPullRequestsIfNeeded(for: repo)
            }
        } else if destination == .ciRuns, let repo = selectedRepo {
            Task { [weak self] in
                await self?.loadCIRunsIfNeeded(for: repo)
            }
        } else if destination == .branches, let repo = selectedRepo {
            Task { [weak self] in
                await self?.loadBranchesIfNeeded(for: repo)
            }
        }
    }

    func closeDetailPanel() {
        selectedDetailDestination = nil
        selectedIssueID = nil
        isIssueComposerVisible = false
        issueDraftTitle = ""
        issueDraftBody = ""
        issueCommentDraft = ""
        issueBranchDraftName = ""
        isIssueBranchComposerVisible = false
        isIssueCommentsLoading = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
        selectedPullRequestID = nil
        isPullRequestCreating = false
        pullRequestActionErrorMessage = nil
        pullRequestActionStatusMessage = nil
        pullRequestDraftTitle = ""
        pullRequestDraftBody = ""
        selectedBranchID = nil
        selectedDestinationInfoItemID = nil
        isPullRequestComposerVisible = false
        pullRequestDraftHeadBranch = nil
    }

    func selectIssuesScope(_ scope: RepoIssuesScope) {
        selectedIssuesScope = scope
        selectedIssueID = nil
        isIssueComposerVisible = false
        issueCommentDraft = ""
        issueBranchDraftName = ""
        isIssueBranchComposerVisible = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
    }

    func filteredIssues(for repo: RepoItem) -> [RepoIssueItem] {
        let issues = loadedIssuesByRepositoryID[repo.id, default: []]

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

    func loadIssuesIfNeeded(for repo: RepoItem) async {
        await loadIssues(for: repo, forceReload: false)
    }

    func reloadIssues(for repo: RepoItem) async {
        await loadIssues(for: repo, forceReload: true)
    }

    func isLoadingIssues(for repo: RepoItem) -> Bool {
        issuesLoadingRepositoryIDs.contains(repo.id)
    }

    func issuesLoadErrorMessage(for repo: RepoItem) -> String? {
        issuesLoadErrorMessageByRepositoryID[repo.id]
    }

    func selectIssue(_ issue: RepoIssueItem, in repo: RepoItem) {
        selectedIssueID = issue.id
        isIssueComposerVisible = false
        issueCommentDraft = ""
        issueBranchDraftName = ""
        isIssueBranchComposerVisible = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil

        Task { [weak self] in
            await self?.loadBranchesIfNeeded(for: repo)
            await self?.refreshIssue(issue, in: repo)
        }
    }

    func closeIssueDetails() {
        selectedIssueID = nil
        issueCommentDraft = ""
        issueBranchDraftName = ""
        isIssueBranchComposerVisible = false
        isIssueCommentsLoading = false
    }

    func selectedIssue(for repo: RepoItem) -> RepoIssueItem? {
        guard let selectedIssueID else { return nil }
        return filteredIssues(for: repo).first(where: { $0.id == selectedIssueID })
    }

    func openIssueComposer() {
        selectedIssueID = nil
        issueCommentDraft = ""
        issueBranchDraftName = ""
        isIssueBranchComposerVisible = false
        issueDraftTitle = ""
        issueDraftBody = ""
        isIssueCommentsLoading = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
        isIssueComposerVisible = true
    }

    func closeIssueComposer() {
        isIssueComposerVisible = false
        issueDraftTitle = ""
        issueDraftBody = ""
    }

    func createIssue(in repo: RepoItem) async {
        let title = trimmedIssueDraftTitle
        guard !title.isEmpty else { return }
        guard !isIssueCreating else { return }

        let description = trimmedIssueDraftBody
        isIssueCreating = true
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil

        defer { isIssueCreating = false }

        do {
            let createdIssue = try await dataProvider.createIssue(
                in: repo,
                title: title,
                body: description.isEmpty ? nil : description
            )

            prependIssue(createdIssue, in: repo)

            selectedIssuesScope = .open
            selectedIssueID = createdIssue.id
            issueCommentDraft = ""
            issueBranchDraftName = ""
            isIssueBranchComposerVisible = false
            issueDraftTitle = ""
            issueDraftBody = ""
            isIssueComposerVisible = false
            issueActionStatusMessage = "Issue #\(createdIssue.number) created in \(repo.name)."
        } catch {
            issueActionErrorMessage = repositoryErrorDescription(error)
        }
    }

    func addIssueComment(to issue: RepoIssueItem, in repo: RepoItem) async {
        let draft = trimmedIssueCommentDraft
        guard !draft.isEmpty else { return }
        guard !isIssueCommentSubmitting else { return }

        isIssueCommentSubmitting = true
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil

        defer { isIssueCommentSubmitting = false }

        do {
            let createdComment = try await dataProvider.addIssueComment(
                to: issue,
                in: repo,
                body: draft
            )

            appendComment(createdComment, to: issue, in: repo)
            issueCommentDraft = ""
            issueActionStatusMessage = "Comment added to issue #\(issue.number)."
        } catch {
            issueActionErrorMessage = repositoryErrorDescription(error)
        }
    }

    func createBranchFromIssue(_ issue: RepoIssueItem, in repo: RepoItem) async {
        guard !isIssueBranchCreating else { return }
        guard issueBranches(for: issue, in: repo).isEmpty else { return }

        isIssueBranchCreating = true
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil

        defer { isIssueBranchCreating = false }

        do {
            let requestedBranchName = normalizedIssueBranchNameInput(issueBranchDraftName, for: issue)
            let branchName = try await dataProvider.createBranch(
                from: issue,
                in: repo,
                branchName: requestedBranchName
            )
            issueBranchDraftName = branchName
            isIssueBranchComposerVisible = false
            markBranchAsOptimistic(named: branchName, in: repo)
            upsertBranch(named: branchName, in: repo)
            registerBranchLink(named: branchName, for: issue, in: repo)
            issueActionStatusMessage = "Branch \(branchName) created from issue #\(issue.number)."
            await reloadBranches(for: repo)
        } catch {
            issueActionErrorMessage = repositoryErrorDescription(error)
        }
    }

    func isLoadingIssueComments(for issue: RepoIssueItem) -> Bool {
        isIssueCommentsLoading && selectedIssueID == issue.id
    }

    func isRefreshingIssue(_ issue: RepoIssueItem) -> Bool {
        issueRefreshingID == issue.id
    }

    func refreshIssue(_ issue: RepoIssueItem, in repo: RepoItem) async {
        if issueRefreshingID == issue.id {
            return
        }

        issueRefreshingID = issue.id
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
        defer {
            if issueRefreshingID == issue.id {
                issueRefreshingID = nil
            }
        }

        do {
            let issues = try await dataProvider.loadIssues(for: repo)
            loadedIssuesByRepositoryID[repo.id] = issues
            synchronizeIssueBranchLinks(for: repo)
            issuesLoadErrorMessageByRepositoryID[repo.id] = nil

            guard let refreshedIssue = issues.first(where: { $0.id == issue.id }) else {
                selectedIssueID = nil
                issueCommentDraft = ""
                issueBranchDraftName = ""
                isIssueBranchComposerVisible = false
                return
            }

            selectedIssueID = refreshedIssue.id
            if !issueBranches(for: refreshedIssue, in: repo).isEmpty {
                isIssueBranchComposerVisible = false
                issueBranchDraftName = ""
            }
            await loadIssueComments(for: refreshedIssue, in: repo, forceReload: true)
        } catch {
            issueActionErrorMessage = repositoryErrorDescription(error)
        }
    }

    func issueBranches(for issue: RepoIssueItem, in repo: RepoItem) -> [String] {
        let key = issueBranchKey(issue: issue, in: repo)
        let linked = issueBranchNamesByIssueKey[key] ?? []
        return linked.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    func prepareIssueBranchDraft(for issue: RepoIssueItem) {
        let trimmed = issueBranchDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            issueBranchDraftName = defaultIssueBranchName(for: issue)
        }
    }

    func openIssueBranchComposer(for issue: RepoIssueItem, in repo: RepoItem) {
        guard issue.isOpen else { return }
        guard issueBranches(for: issue, in: repo).isEmpty else { return }
        prepareIssueBranchDraft(for: issue)
        isIssueBranchComposerVisible = true
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
    }

    func closeIssueBranchComposer() {
        isIssueBranchComposerVisible = false
        issueBranchDraftName = ""
    }

    func selectPullRequestsScope(_ scope: RepoPullRequestsScope) {
        selectedPullRequestsScope = scope
        selectedPullRequestID = nil
        isPullRequestComposerVisible = false
        pullRequestActionErrorMessage = nil
        pullRequestActionStatusMessage = nil
    }

    func loadPullRequestsIfNeeded(for repo: RepoItem) async {
        await loadPullRequests(for: repo, forceReload: false)
    }

    func reloadPullRequests(for repo: RepoItem) async {
        await loadPullRequests(for: repo, forceReload: true)
    }

    func isLoadingPullRequests(for repo: RepoItem) -> Bool {
        pullRequestsLoadingRepositoryIDs.contains(repo.id)
    }

    func pullRequestsLoadErrorMessage(for repo: RepoItem) -> String? {
        pullRequestsLoadErrorMessageByRepositoryID[repo.id]
    }

    func filteredPullRequests(for repo: RepoItem) -> [RepoPullRequestItem] {
        let pullRequests = loadedPullRequestsByRepositoryID[repo.id, default: []]

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

    func selectPullRequest(_ pullRequest: RepoPullRequestItem, in repo: RepoItem) {
        isPullRequestComposerVisible = false
        selectedPullRequestID = pullRequest.id
        pullRequestActionErrorMessage = nil
        pullRequestActionStatusMessage = nil
        Task { [weak self] in
            await self?.loadPullRequestCommits(for: pullRequest, in: repo, forceReload: false)
        }
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
        _ = repo
        return loadedPullRequestCommitsByPullRequestID[pullRequest.id, default: []]
    }

    func isLoadingPullRequestCommits(for pullRequest: RepoPullRequestItem) -> Bool {
        pullRequestCommitsLoadingPullRequestIDs.contains(pullRequest.id)
    }

    func pullRequestCommitsLoadErrorMessage(for pullRequest: RepoPullRequestItem) -> String? {
        pullRequestCommitsLoadErrorMessageByPullRequestID[pullRequest.id]
    }

    func loadPullRequestCommitsIfNeeded(
        for pullRequest: RepoPullRequestItem,
        in repo: RepoItem
    ) async {
        await loadPullRequestCommits(for: pullRequest, in: repo, forceReload: false)
    }

    func reloadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repo: RepoItem
    ) async {
        await loadPullRequestCommits(for: pullRequest, in: repo, forceReload: true)
    }

    func createPullRequest(in repo: RepoItem) async {
        let title = trimmedPullRequestDraftTitle
        guard !title.isEmpty else { return }
        guard !isPullRequestCreating else { return }

        guard let headBranch = pullRequestDraftHeadBranch?.trimmingCharacters(in: .whitespacesAndNewlines),
              !headBranch.isEmpty else {
            pullRequestActionErrorMessage = "Select a head branch first."
            return
        }

        let body = trimmedPullRequestDraftBody
        isPullRequestCreating = true
        pullRequestActionErrorMessage = nil
        pullRequestActionStatusMessage = nil

        defer { isPullRequestCreating = false }

        do {
            let createdPullRequest = try await dataProvider.createPullRequest(
                in: repo,
                title: title,
                body: body.isEmpty ? nil : body,
                headBranch: headBranch,
                baseBranch: repo.branch
            )

            prependPullRequest(createdPullRequest, in: repo)
            selectedPullRequestsScope = .open
            selectedPullRequestID = createdPullRequest.id
            isPullRequestComposerVisible = false
            pullRequestDraftTitle = ""
            pullRequestDraftBody = ""
            pullRequestDraftHeadBranch = nil
            pullRequestActionStatusMessage = "Pull request #\(createdPullRequest.number) created in \(repo.name)."
            applyPullRequestBranchFlags(for: repo)
            await loadPullRequestCommits(for: createdPullRequest, in: repo, forceReload: true)
        } catch {
            pullRequestActionErrorMessage = repositoryErrorDescription(error)
        }
    }

    func branches(for repo: RepoItem) -> [RepoBranchItem] {
        loadedBranchesByRepositoryID[repo.id, default: []]
    }

    func loadBranchesIfNeeded(for repo: RepoItem) async {
        await loadBranches(for: repo, forceReload: false)
        refreshLocalCurrentBranch(for: repo)
    }

    func reloadBranches(for repo: RepoItem) async {
        await loadBranches(for: repo, forceReload: true)
        refreshLocalCurrentBranch(for: repo)
    }

    func isLoadingBranches(for repo: RepoItem) -> Bool {
        branchesLoadingRepositoryIDs.contains(repo.id)
    }

    func branchesLoadErrorMessage(for repo: RepoItem) -> String? {
        branchesLoadErrorMessageByRepositoryID[repo.id]
    }

    func selectedBranch(for repo: RepoItem) -> RepoBranchItem? {
        guard let selectedBranchID else { return nil }
        return branches(for: repo).first(where: { $0.id == selectedBranchID })
    }

    func localCurrentBranch(for repo: RepoItem) -> String? {
        localCurrentBranchByRepositoryID[repo.id]
    }

    func selectBranch(_ branch: RepoBranchItem) {
        selectedBranchID = branch.id
    }

    func closeBranchDetails() {
        selectedBranchID = nil
    }

    func loadCIRunsIfNeeded(for repo: RepoItem) async {
        await loadCIRuns(for: repo, forceReload: false)
    }

    func reloadCIRuns(for repo: RepoItem) async {
        await loadCIRuns(for: repo, forceReload: true)
    }

    func isLoadingCIRuns(for repo: RepoItem) -> Bool {
        ciRunsLoadingRepositoryIDs.contains(repo.id)
    }

    func ciRunsLoadErrorMessage(for repo: RepoItem) -> String? {
        ciRunsLoadErrorMessageByRepositoryID[repo.id]
    }

    func destinationInfoItems(
        for repo: RepoItem,
        destination: RepoDetailDestination
    ) -> [RepoDestinationInfoItem] {
        switch destination {
        case .ciRuns:
            return loadedCIRunsByRepositoryID[repo.id, default: []]
        default:
            return destination.mockInfoItems(repoName: repo.name, branch: repo.branch)
        }
    }

    func selectDestinationInfoItem(_ item: RepoDestinationInfoItem) {
        selectedDestinationInfoItemID = item.id
    }

    func closeDestinationInfoDetails() {
        selectedDestinationInfoItemID = nil
    }

    func selectedDestinationInfoItem(
        for repo: RepoItem,
        destination: RepoDetailDestination
    ) -> RepoDestinationInfoItem? {
        guard let selectedDestinationInfoItemID else { return nil }
        return destinationInfoItems(for: repo, destination: destination)
            .first(where: { $0.id == selectedDestinationInfoItemID })
    }

    func openPullRequestComposer(
        in repo: RepoItem,
        preferredHeadBranch: String? = nil
    ) {
        selectedDetailDestination = .pullRequests
        selectedPullRequestID = nil
        selectedBranchID = nil
        isPullRequestComposerVisible = true
        pullRequestActionErrorMessage = nil
        pullRequestActionStatusMessage = nil
        if let preferredHeadBranch, !preferredHeadBranch.isEmpty {
            pullRequestDraftHeadBranch = preferredHeadBranch
        }
        if pullRequestDraftHeadBranch == nil {
            pullRequestDraftHeadBranch = eligiblePullRequestBranches(for: repo).first?.name
            if pullRequestDraftHeadBranch == nil {
                Task { [weak self] in
                    guard let self else { return }
                    await self.loadBranchesIfNeeded(for: repo)
                    if self.pullRequestDraftHeadBranch == nil {
                        self.pullRequestDraftHeadBranch = self.eligiblePullRequestBranches(for: repo).first?.name
                    }
                    if self.trimmedPullRequestDraftTitle.isEmpty,
                       let headBranch = self.pullRequestDraftHeadBranch {
                        self.pullRequestDraftTitle = self.defaultPullRequestTitle(
                            headBranch: headBranch,
                            baseBranch: repo.branch
                        )
                    }
                }
            }
        }
        if trimmedPullRequestDraftTitle.isEmpty,
           let headBranch = pullRequestDraftHeadBranch {
            pullRequestDraftTitle = defaultPullRequestTitle(headBranch: headBranch, baseBranch: repo.branch)
        }
    }

    func closePullRequestComposer() {
        isPullRequestComposerVisible = false
        pullRequestDraftTitle = ""
        pullRequestDraftBody = ""
    }

    func eligiblePullRequestBranches(for repo: RepoItem) -> [RepoBranchItem] {
        branches(for: repo).filter { branch in
            branch.canOpenPullRequest(baseBranch: repo.branch)
        }
    }

    func selectPullRequestDraftHeadBranch(_ branch: RepoBranchItem, baseBranch: String) {
        pullRequestDraftHeadBranch = branch.name
        if trimmedPullRequestDraftTitle.isEmpty {
            pullRequestDraftTitle = defaultPullRequestTitle(headBranch: branch.name, baseBranch: baseBranch)
        }
    }

    func openInFinder(for repo: RepoItem) -> RepositoryLocalActionResult {
        performLocalAction(.finder, for: repo)
    }

    func openInTerminal(for repo: RepoItem) -> RepositoryLocalActionResult {
        performLocalAction(.terminal, for: repo)
    }

    func checkoutBranch(_ branch: RepoBranchItem, in repo: RepoItem) -> RepositoryLocalActionResult {
        performLocalAction(.checkout(branchName: branch.name), for: repo)
    }

    func openInTerminal(for repo: RepoItem, on branch: RepoBranchItem) -> RepositoryLocalActionResult {
        performLocalAction(.terminalOnBranch(branchName: branch.name), for: repo)
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
                refreshLocalCurrentBranch(for: repo)
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
                    case .checkout(let branchName):
                        try localActionService.checkoutBranch(named: branchName, at: localURL)
                    case .terminalOnBranch(let branchName):
                        try localActionService.checkoutBranch(named: branchName, at: localURL)
                        try localActionService.openInTerminal(at: localURL)
                    }
                }
                refreshLocalCurrentBranch(for: repo)
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

    private func loadIssues(for repo: RepoItem, forceReload: Bool) async {
        if issuesLoadingRepositoryIDs.contains(repo.id) {
            return
        }

        if !forceReload, loadedIssuesByRepositoryID[repo.id] != nil {
            return
        }

        issuesLoadingRepositoryIDs.insert(repo.id)
        issuesLoadErrorMessageByRepositoryID[repo.id] = nil
        defer {
            issuesLoadingRepositoryIDs.remove(repo.id)
        }

        do {
            let issues = try await dataProvider.loadIssues(for: repo)
            loadedIssuesByRepositoryID[repo.id] = issues
            synchronizeIssueBranchLinks(for: repo)
            issuesLoadErrorMessageByRepositoryID[repo.id] = nil

            if let selectedIssueID,
               !issues.contains(where: { $0.id == selectedIssueID }) {
                self.selectedIssueID = nil
                issueCommentDraft = ""
            }
        } catch {
            issuesLoadErrorMessageByRepositoryID[repo.id] = repositoryErrorDescription(error)
            if loadedIssuesByRepositoryID[repo.id] == nil {
                loadedIssuesByRepositoryID[repo.id] = []
            }
        }
    }

    private func loadBranches(for repo: RepoItem, forceReload: Bool) async {
        if branchesLoadingRepositoryIDs.contains(repo.id) {
            return
        }

        if !forceReload, loadedBranchesByRepositoryID[repo.id] != nil {
            return
        }

        branchesLoadingRepositoryIDs.insert(repo.id)
        branchesLoadErrorMessageByRepositoryID[repo.id] = nil
        defer {
            branchesLoadingRepositoryIDs.remove(repo.id)
        }

        do {
            let branches = try await dataProvider.loadBranches(for: repo)
            loadedBranchesByRepositoryID[repo.id] = branches
            preserveOptimisticBranches(in: repo)
            synchronizeIssueBranchLinks(for: repo)
            applyPullRequestBranchFlags(for: repo)
            if let localBranch = localCurrentBranchByRepositoryID[repo.id] {
                markCurrentBranch(named: localBranch, in: repo)
            }
            branchesLoadErrorMessageByRepositoryID[repo.id] = nil

            if let selectedBranchID,
               !branches.contains(where: { $0.id == selectedBranchID }) {
                self.selectedBranchID = nil
            }
        } catch {
            branchesLoadErrorMessageByRepositoryID[repo.id] = repositoryErrorDescription(error)
            if loadedBranchesByRepositoryID[repo.id] == nil {
                loadedBranchesByRepositoryID[repo.id] = []
            }
        }
    }

    private func loadPullRequests(for repo: RepoItem, forceReload: Bool) async {
        if pullRequestsLoadingRepositoryIDs.contains(repo.id) {
            return
        }

        if !forceReload, loadedPullRequestsByRepositoryID[repo.id] != nil {
            return
        }

        pullRequestsLoadingRepositoryIDs.insert(repo.id)
        pullRequestsLoadErrorMessageByRepositoryID[repo.id] = nil
        defer {
            pullRequestsLoadingRepositoryIDs.remove(repo.id)
        }

        do {
            let pullRequests = try await dataProvider.loadPullRequests(for: repo)
            loadedPullRequestsByRepositoryID[repo.id] = pullRequests
            pullRequestsLoadErrorMessageByRepositoryID[repo.id] = nil
            applyPullRequestBranchFlags(for: repo)

            if let selectedPullRequestID,
               !pullRequests.contains(where: { $0.id == selectedPullRequestID }) {
                self.selectedPullRequestID = nil
            }
        } catch {
            pullRequestsLoadErrorMessageByRepositoryID[repo.id] = repositoryErrorDescription(error)
            if loadedPullRequestsByRepositoryID[repo.id] == nil {
                loadedPullRequestsByRepositoryID[repo.id] = []
            }
        }
    }

    private func loadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repo: RepoItem,
        forceReload: Bool
    ) async {
        let commitKey = pullRequest.id

        if pullRequestCommitsLoadingPullRequestIDs.contains(commitKey) {
            return
        }

        if !forceReload, loadedPullRequestCommitsByPullRequestID[commitKey] != nil {
            return
        }

        pullRequestCommitsLoadingPullRequestIDs.insert(commitKey)
        pullRequestCommitsLoadErrorMessageByPullRequestID[commitKey] = nil
        defer {
            pullRequestCommitsLoadingPullRequestIDs.remove(commitKey)
        }

        do {
            let commits = try await dataProvider.loadPullRequestCommits(
                for: pullRequest,
                in: repo
            )
            loadedPullRequestCommitsByPullRequestID[commitKey] = commits
            pullRequestCommitsLoadErrorMessageByPullRequestID[commitKey] = nil
        } catch {
            pullRequestCommitsLoadErrorMessageByPullRequestID[commitKey] = repositoryErrorDescription(error)
            if loadedPullRequestCommitsByPullRequestID[commitKey] == nil {
                loadedPullRequestCommitsByPullRequestID[commitKey] = []
            }
        }
    }

    private func loadCIRuns(for repo: RepoItem, forceReload: Bool) async {
        if ciRunsLoadingRepositoryIDs.contains(repo.id) {
            return
        }

        if !forceReload, loadedCIRunsByRepositoryID[repo.id] != nil {
            return
        }

        ciRunsLoadingRepositoryIDs.insert(repo.id)
        ciRunsLoadErrorMessageByRepositoryID[repo.id] = nil
        defer {
            ciRunsLoadingRepositoryIDs.remove(repo.id)
        }

        do {
            let ciRuns = try await dataProvider.loadCIRuns(for: repo)
            loadedCIRunsByRepositoryID[repo.id] = ciRuns
            ciRunsLoadErrorMessageByRepositoryID[repo.id] = nil

            if let selectedDestinationInfoItemID,
               !ciRuns.contains(where: { $0.id == selectedDestinationInfoItemID }),
               selectedDetailDestination == .ciRuns {
                self.selectedDestinationInfoItemID = nil
            }
        } catch {
            ciRunsLoadErrorMessageByRepositoryID[repo.id] = repositoryErrorDescription(error)
            if loadedCIRunsByRepositoryID[repo.id] == nil {
                loadedCIRunsByRepositoryID[repo.id] = []
            }
        }
    }

    private func loadIssueComments(
        for issue: RepoIssueItem,
        in repo: RepoItem,
        forceReload: Bool
    ) async {
        guard !isIssueCommentsLoading else {
            return
        }

        guard let currentIssue = issueItem(withID: issue.id, in: repo) else {
            return
        }

        if !forceReload && !currentIssue.commentItems.isEmpty {
            return
        }

        if !forceReload && currentIssue.comments <= 0 {
            return
        }

        isIssueCommentsLoading = true
        defer { isIssueCommentsLoading = false }

        do {
            let comments = try await dataProvider.loadIssueComments(for: currentIssue, in: repo)
            replaceIssueComments(for: issue.id, in: repo, comments: comments)
        } catch {
            issueActionErrorMessage = repositoryErrorDescription(error)
        }
    }

    private func prependIssue(_ issue: RepoIssueItem, in repo: RepoItem) {
        var issues = loadedIssuesByRepositoryID[repo.id, default: []]
        issues.removeAll(where: { $0.id == issue.id })
        issues.insert(issue, at: 0)
        loadedIssuesByRepositoryID[repo.id] = issues
    }

    private func prependPullRequest(_ pullRequest: RepoPullRequestItem, in repo: RepoItem) {
        var pullRequests = loadedPullRequestsByRepositoryID[repo.id, default: []]
        pullRequests.removeAll { $0.id == pullRequest.id || $0.number == pullRequest.number }
        pullRequests.insert(pullRequest, at: 0)
        loadedPullRequestsByRepositoryID[repo.id] = pullRequests
    }

    private func replaceIssueComments(
        for issueID: String,
        in repo: RepoItem,
        comments: [RepoIssueCommentItem]
    ) {
        var issues = loadedIssuesByRepositoryID[repo.id, default: []]
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else {
            return
        }

        let sourceIssue = issues[index]
        let updatedCommentsCount = max(sourceIssue.comments, comments.count)
        issues[index] = makeIssueCopy(
            from: sourceIssue,
            comments: updatedCommentsCount,
            commentItems: comments
        )
        loadedIssuesByRepositoryID[repo.id] = issues
    }

    private func appendComment(
        _ comment: RepoIssueCommentItem,
        to issue: RepoIssueItem,
        in repo: RepoItem
    ) {
        var issues = loadedIssuesByRepositoryID[repo.id, default: []]
        guard let index = issues.firstIndex(where: { $0.id == issue.id }) else {
            return
        }

        let sourceIssue = issues[index]
        var comments = sourceIssue.commentItems
        if !comments.contains(where: { $0.id == comment.id }) {
            comments.append(comment)
        }

        let updatedCommentsCount = max(sourceIssue.comments + 1, comments.count)
        issues[index] = makeIssueCopy(
            from: sourceIssue,
            comments: updatedCommentsCount,
            commentItems: comments
        )
        loadedIssuesByRepositoryID[repo.id] = issues
    }

    private func issueItem(withID issueID: String, in repo: RepoItem) -> RepoIssueItem? {
        loadedIssuesByRepositoryID[repo.id, default: []].first(where: { $0.id == issueID })
    }

    private func makeIssueCopy(
        from issue: RepoIssueItem,
        comments: Int? = nil,
        commentItems: [RepoIssueCommentItem]? = nil
    ) -> RepoIssueItem {
        RepoIssueItem(
            id: issue.id,
            number: issue.number,
            title: issue.title,
            body: issue.body,
            labels: issue.labels,
            author: issue.author,
            updatedAgo: issue.updatedAgo,
            comments: comments ?? issue.comments,
            commentItems: commentItems ?? issue.commentItems,
            isOpen: issue.isOpen,
            isMine: issue.isMine
        )
    }

    private func pruneIssuesCache(for repositories: [RepoItem]) {
        let validRepositoryIDs = Set(repositories.map(\.id))
        loadedIssuesByRepositoryID = loadedIssuesByRepositoryID.filter { validRepositoryIDs.contains($0.key) }
        issuesLoadingRepositoryIDs = issuesLoadingRepositoryIDs.intersection(validRepositoryIDs)
        issuesLoadErrorMessageByRepositoryID = issuesLoadErrorMessageByRepositoryID.filter {
            validRepositoryIDs.contains($0.key)
        }
        loadedBranchesByRepositoryID = loadedBranchesByRepositoryID.filter { validRepositoryIDs.contains($0.key) }
        branchesLoadingRepositoryIDs = branchesLoadingRepositoryIDs.intersection(validRepositoryIDs)
        branchesLoadErrorMessageByRepositoryID = branchesLoadErrorMessageByRepositoryID.filter {
            validRepositoryIDs.contains($0.key)
        }
        loadedPullRequestsByRepositoryID = loadedPullRequestsByRepositoryID.filter { validRepositoryIDs.contains($0.key) }
        pullRequestsLoadingRepositoryIDs = pullRequestsLoadingRepositoryIDs.intersection(validRepositoryIDs)
        pullRequestsLoadErrorMessageByRepositoryID = pullRequestsLoadErrorMessageByRepositoryID.filter {
            validRepositoryIDs.contains($0.key)
        }
        let validPullRequestIDs = Set(loadedPullRequestsByRepositoryID.values.flatMap { $0.map(\.id) })
        loadedPullRequestCommitsByPullRequestID = loadedPullRequestCommitsByPullRequestID.filter {
            validPullRequestIDs.contains($0.key)
        }
        pullRequestCommitsLoadingPullRequestIDs = pullRequestCommitsLoadingPullRequestIDs.intersection(validPullRequestIDs)
        pullRequestCommitsLoadErrorMessageByPullRequestID = pullRequestCommitsLoadErrorMessageByPullRequestID.filter {
            validPullRequestIDs.contains($0.key)
        }
        loadedCIRunsByRepositoryID = loadedCIRunsByRepositoryID.filter { validRepositoryIDs.contains($0.key) }
        ciRunsLoadingRepositoryIDs = ciRunsLoadingRepositoryIDs.intersection(validRepositoryIDs)
        ciRunsLoadErrorMessageByRepositoryID = ciRunsLoadErrorMessageByRepositoryID.filter {
            validRepositoryIDs.contains($0.key)
        }
        issueBranchNamesByIssueKey = issueBranchNamesByIssueKey.filter { key, _ in
            validRepositoryIDs.contains(issueRepositoryID(fromIssueBranchKey: key))
        }
        optimisticBranchNamesByRepositoryID = optimisticBranchNamesByRepositoryID.filter { key, _ in
            validRepositoryIDs.contains(key)
        }
        localCurrentBranchByRepositoryID = localCurrentBranchByRepositoryID.filter { key, _ in
            validRepositoryIDs.contains(key)
        }
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

    private func defaultIssueBranchName(for issue: RepoIssueItem) -> String {
        let normalized = issue.title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let suffix = normalized.isEmpty ? "issue" : normalized
        return "issue/\(issue.number)-\(suffix)"
    }

    private func defaultPullRequestTitle(headBranch: String, baseBranch: String) -> String {
        "Merge \(headBranch) into \(baseBranch)"
    }

    private func normalizedIssueBranchNameInput(_ value: String, for issue: RepoIssueItem) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultIssueBranchName(for: issue)
        }

        let collapsedWhitespace = trimmed.replacingOccurrences(
            of: "\\s+",
            with: "-",
            options: .regularExpression
        )
        let normalizedSeparators = collapsedWhitespace.replacingOccurrences(
            of: "-+",
            with: "-",
            options: .regularExpression
        )
        let sanitized = normalizedSeparators.trimmingCharacters(in: CharacterSet(charactersIn: "-/"))
        return sanitized.isEmpty ? defaultIssueBranchName(for: issue) : sanitized
    }

    private func upsertBranch(named branchName: String, in repo: RepoItem) {
        var branches = loadedBranchesByRepositoryID[repo.id, default: []]
        guard !branches.contains(where: { $0.name == branchName }) else { return }

        let newBranch = RepoBranchItem(
            id: "\(repo.id)-branch-\(branchName)",
            name: branchName,
            isDefault: false,
            isCurrent: false,
            aheadBy: 1,
            behindBy: 0,
            hasOpenPullRequest: false,
            updatedAgo: "just now"
        )

        if let defaultIndex = branches.firstIndex(where: { $0.isDefault }) {
            branches.insert(newBranch, at: min(defaultIndex + 1, branches.count))
        } else {
            branches.insert(newBranch, at: 0)
        }

        loadedBranchesByRepositoryID[repo.id] = branches
    }

    private func markCurrentBranch(named branchName: String, in repo: RepoItem) {
        let trimmedBranchName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranchName.isEmpty else { return }

        var branches = loadedBranchesByRepositoryID[repo.id, default: []]
        guard branches.contains(where: { $0.name == trimmedBranchName }) else { return }

        branches = branches.map { branch in
            RepoBranchItem(
                id: branch.id,
                name: branch.name,
                isDefault: branch.isDefault,
                isCurrent: branch.name == trimmedBranchName,
                aheadBy: branch.aheadBy,
                behindBy: branch.behindBy,
                hasOpenPullRequest: branch.hasOpenPullRequest,
                updatedAgo: branch.updatedAgo
            )
        }

        loadedBranchesByRepositoryID[repo.id] = branches
    }

    private func applyPullRequestBranchFlags(for repo: RepoItem) {
        var branches = loadedBranchesByRepositoryID[repo.id, default: []]
        guard !branches.isEmpty else { return }

        let branchesWithOpenPullRequests = Set(
            loadedPullRequestsByRepositoryID[repo.id, default: []]
                .filter(\.isOpen)
                .map(\.sourceBranch)
        )

        branches = branches.map { branch in
            RepoBranchItem(
                id: branch.id,
                name: branch.name,
                isDefault: branch.isDefault,
                isCurrent: branch.isCurrent,
                aheadBy: branch.aheadBy,
                behindBy: branch.behindBy,
                hasOpenPullRequest: branchesWithOpenPullRequests.contains(branch.name),
                updatedAgo: branch.updatedAgo
            )
        }

        loadedBranchesByRepositoryID[repo.id] = branches
    }

    private func refreshLocalCurrentBranch(for repo: RepoItem) {
        do {
            let rootURL = try localRootProvider.currentRootURL()
            let localMatch = localResolver.resolve(repo: repo, rootURL: rootURL)

            switch localMatch {
            case .rootNotConfigured, .missing:
                localCurrentBranchByRepositoryID.removeValue(forKey: repo.id)
            case .matched(let localURL):
                let localBranchName = try withRootAccess(rootURL: rootURL) {
                    try localActionService.currentBranchName(at: localURL)
                }

                guard let localBranchName else {
                    localCurrentBranchByRepositoryID.removeValue(forKey: repo.id)
                    return
                }

                let trimmedLocalBranch = localBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLocalBranch.isEmpty else {
                    localCurrentBranchByRepositoryID.removeValue(forKey: repo.id)
                    return
                }

                localCurrentBranchByRepositoryID[repo.id] = trimmedLocalBranch
                markCurrentBranch(named: trimmedLocalBranch, in: repo)
            }
        } catch {
            localCurrentBranchByRepositoryID.removeValue(forKey: repo.id)
        }
    }

    private func markBranchAsOptimistic(named branchName: String, in repo: RepoItem) {
        var optimisticNames = optimisticBranchNamesByRepositoryID[repo.id, default: []]
        optimisticNames.insert(branchName)
        optimisticBranchNamesByRepositoryID[repo.id] = optimisticNames
    }

    private func preserveOptimisticBranches(in repo: RepoItem) {
        let optimisticNames = optimisticBranchNamesByRepositoryID[repo.id, default: []]
        guard !optimisticNames.isEmpty else { return }

        let loadedNames = Set(loadedBranchesByRepositoryID[repo.id, default: []].map(\.name))
        let unresolvedNames = optimisticNames.subtracting(loadedNames)

        if unresolvedNames.isEmpty {
            optimisticBranchNamesByRepositoryID.removeValue(forKey: repo.id)
            return
        }

        for unresolvedName in unresolvedNames {
            upsertBranch(named: unresolvedName, in: repo)
        }

        optimisticBranchNamesByRepositoryID[repo.id] = unresolvedNames
    }

    private func registerBranchLink(named branchName: String, for issue: RepoIssueItem, in repo: RepoItem) {
        let key = issueBranchKey(issue: issue, in: repo)
        var linked = Set(issueBranchNamesByIssueKey[key] ?? [])
        linked.insert(branchName)
        issueBranchNamesByIssueKey[key] = linked.sorted()
    }

    private func synchronizeIssueBranchLinks(for repo: RepoItem) {
        let issues = loadedIssuesByRepositoryID[repo.id, default: []]
        let branchNames = loadedBranchesByRepositoryID[repo.id, default: []].map(\.name)
        let branchNameSet = Set(branchNames)
        let validIssueKeys = Set(issues.map { issueBranchKey(issue: $0, in: repo) })

        issueBranchNamesByIssueKey = issueBranchNamesByIssueKey.filter { key, _ in
            guard issueRepositoryID(fromIssueBranchKey: key) == repo.id else {
                return true
            }
            return validIssueKeys.contains(key)
        }

        for issue in issues {
            let key = issueBranchKey(issue: issue, in: repo)
            var linked = Set(issueBranchNamesByIssueKey[key] ?? [])
            linked = linked.intersection(branchNameSet)

            for branchName in branchNames where isBranchName(branchName, linkedToIssueNumber: issue.number) {
                linked.insert(branchName)
            }

            if linked.isEmpty {
                issueBranchNamesByIssueKey.removeValue(forKey: key)
            } else {
                issueBranchNamesByIssueKey[key] = linked.sorted()
            }
        }
    }

    private func isBranchName(_ branchName: String, linkedToIssueNumber issueNumber: Int) -> Bool {
        let lowercased = branchName.lowercased()
        let normalized = lowercased.replacingOccurrences(of: "_", with: "-")
        let issueNumberToken = "\(issueNumber)"

        if normalized == "issue/\(issueNumberToken)" || normalized.hasPrefix("issue/\(issueNumberToken)-") {
            return true
        }
        if normalized == "issue-\(issueNumberToken)" || normalized.hasPrefix("issue-\(issueNumberToken)-") {
            return true
        }
        if normalized.hasPrefix("issues/\(issueNumberToken)-") || normalized.hasPrefix("issues-\(issueNumberToken)-") {
            return true
        }
        return false
    }

    private func issueBranchKey(issue: RepoIssueItem, in repo: RepoItem) -> String {
        "\(repo.id)#\(issue.number)"
    }

    private func issueRepositoryID(fromIssueBranchKey key: String) -> String {
        guard let separatorIndex = key.lastIndex(of: "#") else {
            return key
        }
        return String(key[..<separatorIndex])
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

    private var trimmedIssueDraftTitle: String {
        issueDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedIssueDraftBody: String {
        issueDraftBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPullRequestDraftTitle: String {
        pullRequestDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPullRequestDraftBody: String {
        pullRequestDraftBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
