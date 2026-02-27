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

    init(
        gitHubAPIService: GitHubAPIServicing,
        gitHubTokenStore: GitHubTokenStoring
    ) {
        self.gitHubAPIService = gitHubAPIService
        self.gitHubTokenStore = gitHubTokenStore
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

    func loadPullRequests(for repository: RepoItem) async throws -> [RepoPullRequestItem] {
        let token = try accessToken()
        let viewerLogin = try await gitHubAPIService.fetchViewerLogin(accessToken: token).lowercased()
        let pullRequests = try await gitHubAPIService.fetchPullRequests(
            accessToken: token,
            repositoryFullName: repository.name
        )

        return pullRequests.map { pullRequest in
            mapToPullRequestItem(
                pullRequest,
                repositoryID: repository.id,
                viewerLogin: viewerLogin
            )
        }
    }

    func loadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repository: RepoItem
    ) async throws -> [RepoPullRequestCommitItem] {
        let token = try accessToken()
        let commits = try await gitHubAPIService.fetchPullRequestCommits(
            accessToken: token,
            repositoryFullName: repository.name,
            pullRequestNumber: pullRequest.number
        )

        return commits.map(mapToPullRequestCommitItem)
    }

    func createPullRequest(
        in repository: RepoItem,
        title: String,
        body: String?,
        headBranch: String,
        baseBranch: String
    ) async throws -> RepoPullRequestItem {
        let token = try accessToken()
        let viewerLogin = try await gitHubAPIService.fetchViewerLogin(accessToken: token).lowercased()
        let createdPullRequest = try await gitHubAPIService.createPullRequest(
            accessToken: token,
            repositoryFullName: repository.name,
            title: title,
            body: body,
            head: headBranch,
            base: baseBranch
        )

        let pullRequests = try await gitHubAPIService.fetchPullRequests(
            accessToken: token,
            repositoryFullName: repository.name
        )

        if let matchedPullRequest = pullRequests.first(where: { $0.number == createdPullRequest.number }) {
            return mapToPullRequestItem(
                matchedPullRequest,
                repositoryID: repository.id,
                viewerLogin: viewerLogin
            )
        }

        return RepoPullRequestItem(
            id: "\(repository.id)-pr-\(createdPullRequest.number)",
            number: createdPullRequest.number,
            title: createdPullRequest.title,
            author: viewerLogin,
            sourceBranch: headBranch,
            targetBranch: baseBranch,
            updatedAgo: "just now",
            comments: 0,
            changedFiles: 0,
            commits: 0,
            additions: 0,
            deletions: 0,
            isOpen: true,
            isMerged: false,
            isMine: true
        )
    }

    func loadCIRuns(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        let token = try accessToken()
        let workflowRuns = try await gitHubAPIService.fetchWorkflowRuns(
            accessToken: token,
            repositoryFullName: repository.name
        )

        return workflowRuns.map { run in
            mapToCIRunInfoItem(run, repository: repository)
        }
    }

    func loadOpenCommits(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        let token = try accessToken()
        let commits = try await gitHubAPIService.fetchRepositoryCommits(
            accessToken: token,
            repositoryFullName: repository.name,
            branch: repository.branch
        )

        return commits.map { commit in
            mapToOpenCommitInfoItem(commit, repository: repository)
        }
    }

    func loadTags(for repository: RepoItem) async throws -> [RepoDestinationInfoItem] {
        let token = try accessToken()
        let tags = try await gitHubAPIService.fetchRepositoryTags(
            accessToken: token,
            repositoryFullName: repository.name
        )

        return tags.map { tag in
            mapToTagInfoItem(tag, repository: repository)
        }
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

    private func mapToPullRequestItem(
        _ pullRequest: GitHubPullRequest,
        repositoryID: String,
        viewerLogin: String
    ) -> RepoPullRequestItem {
        RepoPullRequestItem(
            id: "\(repositoryID)-pr-\(pullRequest.number)",
            number: pullRequest.number,
            title: pullRequest.title,
            author: pullRequest.authorLogin,
            sourceBranch: pullRequest.sourceBranch,
            targetBranch: pullRequest.targetBranch,
            updatedAgo: relativeTime(from: pullRequest.updatedAt),
            comments: max(0, pullRequest.comments),
            changedFiles: max(0, pullRequest.changedFiles),
            commits: max(0, pullRequest.commits),
            additions: max(0, pullRequest.additions),
            deletions: max(0, pullRequest.deletions),
            isOpen: pullRequest.isOpen,
            isMerged: pullRequest.isMerged,
            isMine: pullRequest.authorLogin.lowercased() == viewerLogin
        )
    }

    private func mapToPullRequestCommitItem(_ commit: GitHubPullRequestCommit) -> RepoPullRequestCommitItem {
        RepoPullRequestCommitItem(
            id: commit.id,
            sha: String(commit.sha.prefix(7)),
            message: commit.message,
            author: commit.authorLogin,
            committedAgo: relativeTime(from: commit.committedAt)
        )
    }

    private func mapToCIRunInfoItem(
        _ run: GitHubWorkflowRun,
        repository: RepoItem
    ) -> RepoDestinationInfoItem {
        let statusText = ciRunStatusText(status: run.status, conclusion: run.conclusion)
        let branchName = {
            let trimmed = run.headBranch?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? repository.branch : trimmed
        }()
        let metadataDate = run.startedAt ?? run.createdAt ?? run.updatedAt
        let metadata = metadataDate.map { "Started \(relativeTime(from: $0))" } ?? "Updated recently"
        let summary = "Workflow run for \(ciLabel(run.event)) on \(branchName) is \(statusText.lowercased())."

        var bulletPoints: [String] = []
        if let event = run.event?.trimmingCharacters(in: .whitespacesAndNewlines), !event.isEmpty {
            bulletPoints.append("Event: \(ciLabel(event))")
        }
        if let actor = run.actorLogin?.trimmingCharacters(in: .whitespacesAndNewlines), !actor.isEmpty {
            bulletPoints.append("Actor: \(actor)")
        }
        if let headSHA = run.headSHA?.trimmingCharacters(in: .whitespacesAndNewlines), !headSHA.isEmpty {
            bulletPoints.append("Commit: \(String(headSHA.prefix(7)))")
        }
        if let detailsURL = run.htmlURL?.absoluteString, !detailsURL.isEmpty {
            bulletPoints.append("Details: \(detailsURL)")
        }

        return RepoDestinationInfoItem(
            id: run.id,
            title: run.name,
            subtitle: "Run #\(run.runNumber) • \(branchName)",
            status: statusText,
            metadata: metadata,
            summary: summary,
            bulletPoints: bulletPoints,
            trailingValue: ciRunDuration(
                status: run.status,
                startedAt: run.startedAt ?? run.createdAt,
                updatedAt: run.updatedAt
            )
        )
    }

    private func mapToOpenCommitInfoItem(
        _ commit: GitHubRepositoryCommit,
        repository: RepoItem
    ) -> RepoDestinationInfoItem {
        let shortSHA = String(commit.sha.prefix(7))
        let metadata = commit.committedAt.map { "Committed \(relativeTime(from: $0))" } ?? "Committed recently"
        let summary = "Recent commit on \(repository.branch) by \(commit.authorLogin)."
        var bulletPoints = [
            "Branch: \(repository.branch)",
            "Commit: \(shortSHA)"
        ]

        if let detailsURL = commit.htmlURL?.absoluteString, !detailsURL.isEmpty {
            bulletPoints.append("Details: \(detailsURL)")
        }

        return RepoDestinationInfoItem(
            id: commit.id,
            title: commit.message,
            subtitle: "\(shortSHA) • \(commit.authorLogin)",
            status: "Open",
            metadata: metadata,
            summary: summary,
            bulletPoints: bulletPoints,
            trailingValue: repository.branch
        )
    }

    private func mapToTagInfoItem(
        _ tag: GitHubRepositoryTag,
        repository: RepoItem
    ) -> RepoDestinationInfoItem {
        let shortSHA = String(tag.commitSHA.prefix(7))
        var bulletPoints = [
            "Commit: \(shortSHA)",
            "Branch: \(repository.branch)"
        ]

        if let tarballURL = tag.tarballURL?.absoluteString, !tarballURL.isEmpty {
            bulletPoints.append("Tarball: \(tarballURL)")
        }
        if let zipballURL = tag.zipballURL?.absoluteString, !zipballURL.isEmpty {
            bulletPoints.append("Zipball: \(zipballURL)")
        }

        return RepoDestinationInfoItem(
            id: tag.id,
            title: tag.name,
            subtitle: "Commit \(shortSHA)",
            status: "Active",
            metadata: "Updated recently",
            summary: "Tag \(tag.name) points to commit \(shortSHA) on \(repository.name).",
            bulletPoints: bulletPoints,
            trailingValue: nil
        )
    }

    private func ciRunStatusText(status: String, conclusion: String?) -> String {
        let normalizedStatus = status.lowercased()

        if normalizedStatus == "completed" {
            switch conclusion?.lowercased() {
            case "success":
                return "Success"
            case "failure":
                return "Failure"
            case "cancelled":
                return "Cancelled"
            case "timed_out":
                return "Timed Out"
            case "neutral":
                return "Neutral"
            case "skipped":
                return "Skipped"
            case "action_required":
                return "Action Required"
            case "startup_failure":
                return "Startup Failure"
            case "stale":
                return "Stale"
            default:
                return "Completed"
            }
        }

        if normalizedStatus == "in_progress" {
            return "In Progress"
        }

        if normalizedStatus == "queued" {
            return "Queued"
        }

        if normalizedStatus == "requested" {
            return "Requested"
        }

        return ciLabel(normalizedStatus)
    }

    private func ciRunDuration(status: String, startedAt: Date?, updatedAt: Date?) -> String? {
        guard let startedAt else { return nil }

        let normalizedStatus = status.lowercased()
        let endDate: Date
        if normalizedStatus == "in_progress" {
            endDate = Date()
        } else if let updatedAt {
            endDate = updatedAt
        } else {
            return nil
        }

        let duration = max(0, Int(endDate.timeIntervalSince(startedAt)))
        if duration < 60 {
            return "\(duration)s"
        }

        let hours = duration / 3_600
        let minutes = (duration % 3_600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m \(seconds)s"
    }

    private func ciLabel(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "workflow"
        }

        return value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
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
            ciRuns: 0,
            discussions: metric("\(repository.fullName)-discussions", min: 0, max: 22),
            tags: 0,
            branches: metric("\(repository.fullName)-branches", min: 1, max: 12),
            contributors: metric("\(repository.fullName)-contributors", min: 1, max: 14),
            openCommits: 0
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
