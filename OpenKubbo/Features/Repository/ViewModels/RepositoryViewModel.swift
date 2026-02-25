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
            isIssueComposerVisible = false
            issueDraftTitle = ""
            issueDraftBody = ""
            issueCommentDraft = ""
            selectedPullRequestID = nil
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
    @Published private(set) var isIssueCommentsLoading = false
    @Published private(set) var issueRefreshingID: String?
    @Published private(set) var issueActionErrorMessage: String?
    @Published private(set) var issueActionStatusMessage: String?
    @Published var issueDraftTitle = ""
    @Published var issueDraftBody = ""
    @Published var issueCommentDraft = ""
    @Published var selectedPullRequestsScope: RepoPullRequestsScope = .open
    @Published var selectedPullRequestID: String?
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
    @Published private(set) var loadedIssuesByRepositoryID: [String: [RepoIssueItem]] = [:]
    @Published private(set) var issuesLoadingRepositoryIDs: Set<String> = []
    @Published private(set) var issuesLoadErrorMessageByRepositoryID: [String: String] = [:]

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
        isIssueComposerVisible = false
        issueDraftTitle = ""
        issueDraftBody = ""
        issueCommentDraft = ""
        isIssueCommentsLoading = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
        selectedPullRequestID = nil
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
            issueActionErrorMessage = nil
            issueActionStatusMessage = nil
        } else {
            isIssueComposerVisible = false
            issueDraftTitle = ""
            issueDraftBody = ""
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
        selectedDestinationInfoItemID = nil
        selectedDetailDestination = destination

        if destination == .issues, let repo = selectedRepo {
            Task { [weak self] in
                await self?.loadIssuesIfNeeded(for: repo)
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
        isIssueCommentsLoading = false
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil
        selectedPullRequestID = nil
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
        issueActionErrorMessage = nil
        issueActionStatusMessage = nil

        Task { [weak self] in
            await self?.refreshIssue(issue, in: repo)
        }
    }

    func closeIssueDetails() {
        selectedIssueID = nil
        issueCommentDraft = ""
        isIssueCommentsLoading = false
    }

    func selectedIssue(for repo: RepoItem) -> RepoIssueItem? {
        guard let selectedIssueID else { return nil }
        return filteredIssues(for: repo).first(where: { $0.id == selectedIssueID })
    }

    func openIssueComposer() {
        selectedIssueID = nil
        issueCommentDraft = ""
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
            issuesLoadErrorMessageByRepositoryID[repo.id] = nil

            guard let refreshedIssue = issues.first(where: { $0.id == issue.id }) else {
                selectedIssueID = nil
                issueCommentDraft = ""
                return
            }

            selectedIssueID = refreshedIssue.id
            await loadIssueComments(for: refreshedIssue, in: repo, forceReload: true)
        } catch {
            issueActionErrorMessage = repositoryErrorDescription(error)
        }
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

    func destinationInfoItems(
        for repo: RepoItem,
        destination: RepoDetailDestination
    ) -> [RepoDestinationInfoItem] {
        destination.mockInfoItems(repoName: repo.name, branch: repo.branch)
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

    private var trimmedIssueDraftTitle: String {
        issueDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedIssueDraftBody: String {
        issueDraftBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
