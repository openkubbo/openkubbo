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
        let token = try accessToken()

        let repositories = try await gitHubAPIService.fetchRepositories(accessToken: token)

        return repositories.enumerated().map { index, repository in
            mapToRepoItem(repository, index: index)
        }
    }

    func loadContributionCalendar() async throws -> [RepoContributionDay] {
        let token = try accessToken()
        let calendar = try await gitHubAPIService.fetchContributionCalendar(accessToken: token)

        return calendar.days.map { day in
            RepoContributionDay(
                dateKey: day.dateKey,
                count: max(0, day.contributionCount)
            )
        }
    }

    func loadIssues(for repository: RepoItem) async throws -> [RepoIssueItem] {
        let token = try accessToken()
        let viewerLogin = try await gitHubAPIService.fetchViewerLogin(accessToken: token).lowercased()
        let issues = try await gitHubAPIService.fetchIssues(
            accessToken: token,
            repositoryFullName: repository.name
        )

        return issues.map { issue in
            mapToIssueItem(issue, repositoryID: repository.id, viewerLogin: viewerLogin)
        }
    }

    func loadIssueComments(
        for issue: RepoIssueItem,
        in repository: RepoItem
    ) async throws -> [RepoIssueCommentItem] {
        let token = try accessToken()
        let comments = try await gitHubAPIService.fetchIssueComments(
            accessToken: token,
            repositoryFullName: repository.name,
            issueNumber: issue.number
        )

        return comments.map(mapToIssueCommentItem)
    }

    func createIssue(
        in repository: RepoItem,
        title: String,
        body: String?
    ) async throws -> RepoIssueItem {
        let token = try accessToken()
        let viewerLogin = try await gitHubAPIService.fetchViewerLogin(accessToken: token)
        let createdIssue = try await gitHubAPIService.createIssue(
            accessToken: token,
            repositoryFullName: repository.name,
            title: title,
            body: body
        )

        return RepoIssueItem(
            id: "\(repository.id)-issue-\(createdIssue.number)",
            number: createdIssue.number,
            title: createdIssue.title,
            body: normalizedIssueBody(body),
            labels: [],
            author: viewerLogin,
            updatedAgo: "just now",
            comments: 0,
            commentItems: [],
            isOpen: true,
            isMine: true
        )
    }

    func addIssueComment(
        to issue: RepoIssueItem,
        in repository: RepoItem,
        body: String
    ) async throws -> RepoIssueCommentItem {
        let token = try accessToken()
        let createdComment = try await gitHubAPIService.createIssueComment(
            accessToken: token,
            repositoryFullName: repository.name,
            issueNumber: issue.number,
            body: body
        )

        return mapToIssueCommentItem(createdComment)
    }

    func createBranch(
        from issue: RepoIssueItem,
        in repository: RepoItem,
        branchName: String
    ) async throws -> String {
        let token = try accessToken()
        let fetchedBranches = try await gitHubAPIService.fetchBranches(
            accessToken: token,
            repositoryFullName: repository.name
        )

        let baseBranch = fetchedBranches.first(where: { $0.name == repository.branch }) ?? fetchedBranches.first
        guard let baseBranch else {
            throw GitHubAPIError.invalidParameters("Base branch not found for this repository.")
        }

        let normalizedRequestedBranchName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBranchName = normalizedRequestedBranchName.isEmpty
            ? issueBranchName(for: issue)
            : normalizedRequestedBranchName
        let createdBranch = try await gitHubAPIService.createBranch(
            accessToken: token,
            repositoryFullName: repository.name,
            branchName: resolvedBranchName,
            fromCommitSHA: baseBranch.commitSHA
        )
        return createdBranch.name
    }

    func loadPullRequests(for repository: RepoItem) -> [RepoPullRequestItem] {
        fallbackIssuesProvider.loadPullRequests(for: repository)
    }

    func loadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repository: RepoItem
    ) -> [RepoPullRequestCommitItem] {
        fallbackIssuesProvider.loadPullRequestCommits(for: pullRequest, in: repository)
    }

    func loadBranches(for repository: RepoItem) async throws -> [RepoBranchItem] {
        let token = try accessToken()
        let fetchedBranches = try await gitHubAPIService.fetchBranches(
            accessToken: token,
            repositoryFullName: repository.name
        )

        let mapped = fetchedBranches.map { branch in
            mapToBranchItem(branch, repository: repository)
        }

        return mapped.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func accessToken() throws -> String {
        guard let token = gitHubTokenStore.token(),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryDataError.notAuthenticated
        }

        return token
    }

    private func mapToIssueItem(
        _ issue: GitHubIssue,
        repositoryID: String,
        viewerLogin: String
    ) -> RepoIssueItem {
        let issueLabels = issue.labels.map {
            RepoIssueLabel(
                id: "\(repositoryID)-issue-label-\($0.id)",
                title: $0.name,
                kind: mapIssueLabelKind($0.name)
            )
        }

        return RepoIssueItem(
            id: issue.id,
            number: issue.number,
            title: issue.title,
            body: normalizedIssueBody(issue.body),
            labels: issueLabels,
            author: issue.authorLogin,
            updatedAgo: relativeTime(from: issue.updatedAt),
            comments: issue.comments,
            commentItems: [],
            isOpen: issue.isOpen,
            isMine: issue.authorLogin.lowercased() == viewerLogin
        )
    }

    private func mapToIssueCommentItem(_ comment: GitHubIssueComment) -> RepoIssueCommentItem {
        RepoIssueCommentItem(
            id: comment.id,
            author: comment.authorLogin,
            body: comment.body,
            updatedAgo: relativeTime(from: comment.updatedAt)
        )
    }

    private func mapIssueLabelKind(_ label: String) -> RepoIssueLabelKind {
        let normalized = label.lowercased()

        if normalized.contains("bug") {
            return .bug
        }
        if normalized.contains("help wanted") {
            return .helpWanted
        }
        if normalized.contains("good first issue") {
            return .goodFirstIssue
        }
        return .enhancement
    }

    private func normalizedIssueBody(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "No description provided." : trimmed
    }

    private func mapToBranchItem(
        _ branch: GitHubBranch,
        repository: RepoItem
    ) -> RepoBranchItem {
        let isDefault = branch.name == repository.branch
        let isCurrent = isDefault

        return RepoBranchItem(
            id: "\(repository.id)-branch-\(branch.name)",
            name: branch.name,
            isDefault: isDefault,
            isCurrent: isCurrent,
            aheadBy: isDefault ? 0 : 1,
            behindBy: 0,
            hasOpenPullRequest: false,
            updatedAgo: seededRelativeTime("\(repository.id)-\(branch.name)-branch-updated")
        )
    }

    private func issueBranchName(for issue: RepoIssueItem) -> String {
        let normalizedTitle = issue.title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let suffix = normalizedTitle.isEmpty ? "issue" : normalizedTitle
        return "issue/\(issue.number)-\(suffix)"
    }

    private func seededRelativeTime(_ key: String) -> String {
        let totalMinutes = Int(seededValue(key) % 1_440)

        if totalMinutes < 60 {
            return "\(max(1, totalMinutes)) min. ago"
        }

        let totalHours = totalMinutes / 60
        if totalHours < 24 {
            return "\(totalHours) hr. ago"
        }

        let days = max(1, totalHours / 24)
        return "\(days) day" + (days == 1 ? " ago" : "s ago")
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
