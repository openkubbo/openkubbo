import Foundation

protocol RepositoryDataProviding {
    func loadRepositories() async throws -> [RepoItem]
    func loadIssues(for repository: RepoItem) async throws -> [RepoIssueItem]
    func loadIssueComments(
        for issue: RepoIssueItem,
        in repository: RepoItem
    ) async throws -> [RepoIssueCommentItem]
    func createIssue(
        in repository: RepoItem,
        title: String,
        body: String?
    ) async throws -> RepoIssueItem
    func addIssueComment(
        to issue: RepoIssueItem,
        in repository: RepoItem,
        body: String
    ) async throws -> RepoIssueCommentItem
    func loadPullRequests(for repository: RepoItem) -> [RepoPullRequestItem]
    func loadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repository: RepoItem
    ) -> [RepoPullRequestCommitItem]
    func loadBranches(for repository: RepoItem) async throws -> [RepoBranchItem]
}

struct MockRepositoryDataProvider: RepositoryDataProviding {
    func loadRepositories() async throws -> [RepoItem] {
        [
            RepoItem(
                id: "tarikvillalobos/postme",
                name: "tarikvillalobos/postme",
                sshCloneURL: "git@github.com:tarikvillalobos/postme.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/postme.git",
                visibility: .openSource,
                issues: 2,
                prs: 1,
                stars: 124,
                branch: "main",
                updatedAgo: "1 min. ago",
                isPinned: true,
                isWork: false,
                releases: 12,
                ciRuns: 1232,
                discussions: 0,
                tags: 13,
                branches: 1,
                contributors: 3,
                openCommits: 24
            ),
            RepoItem(
                id: "tarikvillalobos/rentify",
                name: "tarikvillalobos/rentify",
                sshCloneURL: "git@github.com:tarikvillalobos/rentify.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/rentify.git",
                visibility: .private,
                issues: 4,
                prs: 5,
                stars: 892,
                branch: "main",
                updatedAgo: "14 min. ago",
                isPinned: true,
                isWork: true,
                releases: 9,
                ciRuns: 761,
                discussions: 3,
                tags: 18,
                branches: 4,
                contributors: 6,
                openCommits: 42
            ),
            RepoItem(
                id: "tarikvillalobos/time-zones",
                name: "tarikvillalobos/time-zones",
                sshCloneURL: "git@github.com:tarikvillalobos/time-zones.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/time-zones.git",
                visibility: .openSource,
                issues: 1,
                prs: 0,
                stars: 340,
                branch: "dev",
                updatedAgo: "13 min. ago",
                isPinned: false,
                isWork: false,
                releases: 4,
                ciRuns: 188,
                discussions: 1,
                tags: 7,
                branches: 3,
                contributors: 2,
                openCommits: 11
            ),
            RepoItem(
                id: "tarikvillalobos/squaddy",
                name: "tarikvillalobos/squaddy",
                sshCloneURL: "git@github.com:tarikvillalobos/squaddy.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/squaddy.git",
                visibility: .private,
                issues: 0,
                prs: 2,
                stars: 56,
                branch: "master",
                updatedAgo: "1 hr. ago",
                isPinned: false,
                isWork: true,
                releases: 2,
                ciRuns: 43,
                discussions: 0,
                tags: 3,
                branches: 2,
                contributors: 2,
                openCommits: 7
            ),
            RepoItem(
                id: "tarikvillalobos/api-kit",
                name: "tarikvillalobos/api-kit",
                sshCloneURL: "git@github.com:tarikvillalobos/api-kit.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/api-kit.git",
                visibility: .openSource,
                issues: 3,
                prs: 1,
                stars: 1205,
                branch: "feature/v2",
                updatedAgo: "30 min. ago",
                isPinned: true,
                isWork: true,
                releases: 21,
                ciRuns: 3011,
                discussions: 7,
                tags: 25,
                branches: 8,
                contributors: 11,
                openCommits: 63
            ),
            RepoItem(
                id: "tarikvillalobos/mnemonic",
                name: "tarikvillalobos/mnemonic",
                sshCloneURL: "git@github.com:tarikvillalobos/mnemonic.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/mnemonic.git",
                visibility: .private,
                issues: 0,
                prs: 0,
                stars: 78,
                branch: "main",
                updatedAgo: "2 hr. ago",
                isPinned: false,
                isWork: false,
                releases: 1,
                ciRuns: 17,
                discussions: 0,
                tags: 1,
                branches: 1,
                contributors: 1,
                openCommits: 4
            ),
            RepoItem(
                id: "tarikvillalobos/open-tasks",
                name: "tarikvillalobos/open-tasks",
                sshCloneURL: "git@github.com:tarikvillalobos/open-tasks.git",
                httpsCloneURL: "https://github.com/tarikvillalobos/open-tasks.git",
                visibility: .openSource,
                issues: 5,
                prs: 3,
                stars: 412,
                branch: "main",
                updatedAgo: "4 min. ago",
                isPinned: true,
                isWork: true,
                releases: 14,
                ciRuns: 942,
                discussions: 5,
                tags: 16,
                branches: 5,
                contributors: 8,
                openCommits: 38
            )
        ]
    }

    func loadIssues(for repository: RepoItem) async throws -> [RepoIssueItem] {
        [
            RepoIssueItem(
                id: "\(repository.id)-26",
                number: 26,
                title: "Refactor: Glass effect performance",
                body: "Current glass effects are triggering high redraw cost on macOS and hurting scroll performance in large task lists.\n\nExpected:\n- Keep blur/glass visual quality.\n- Reduce expensive invalidations while scrolling.\n- Keep parity in dark and light themes.\n\nNotes:\n- Focus first on settings and repository overlays where repaint cost is highest.",
                labels: [RepoIssueLabel(id: "enhancement-26", title: "enhancement", kind: .enhancement)],
                author: "tarikvillalobos",
                updatedAgo: "20 min. ago",
                comments: 0,
                commentItems: [],
                isOpen: true,
                isMine: true
            ),
            RepoIssueItem(
                id: "\(repository.id)-25",
                number: 25,
                title: "Chat UI doesn't disappear if disabled in settings.",
                body: "When disabling the chat interface in Settings, the chat panel remains mounted and visible until app restart.\n\nSteps:\n1. Open Settings.\n2. Disable chat.\n3. Return to main screen.\n\nExpected: chat panel should disappear immediately.\nActual: panel remains visible.",
                labels: [RepoIssueLabel(id: "bug-25", title: "bug", kind: .bug)],
                author: "tarikvillalobos",
                updatedAgo: "21 min. ago",
                comments: 0,
                commentItems: [],
                isOpen: true,
                isMine: true
            ),
            RepoIssueItem(
                id: "\(repository.id)-24",
                number: 24,
                title: "Build fails on Windows: 'rm' command not recognized in clean scripts",
                body: "The clean script currently assumes a Unix shell and uses `rm`, which fails on Windows environments.\n\nProposal:\n- Replace shell-specific cleanup with Swift/Node cross-platform removal.\n- Add CI check for Windows build parity.",
                labels: [
                    RepoIssueLabel(id: "bug-24", title: "bug", kind: .bug),
                    RepoIssueLabel(id: "help-24", title: "help wanted", kind: .helpWanted),
                    RepoIssueLabel(id: "good-24", title: "good first issue", kind: .goodFirstIssue)
                ],
                author: "Ehtz",
                updatedAgo: "1 hr. ago",
                comments: 1,
                commentItems: [
                    RepoIssueCommentItem(
                        id: "\(repository.id)-24-comment-1",
                        author: "tarikvillalobos",
                        body: "Good catch. We can replace the cleanup step with a cross-platform script and wire it to CI to prevent regressions.",
                        updatedAgo: "52 min. ago"
                    )
                ],
                isOpen: true,
                isMine: false
            ),
            RepoIssueItem(
                id: "\(repository.id)-21",
                number: 21,
                title: "Mozila extension",
                body: "Need to review naming and packaging for browser extension release.\n\nRequested:\n- Confirm final Firefox-compatible bundle.\n- Align naming to `Mozilla` before publishing.\n- Add release notes template for extension updates.",
                labels: [
                    RepoIssueLabel(id: "help-21", title: "help wanted", kind: .helpWanted),
                    RepoIssueLabel(id: "good-21", title: "good first issue", kind: .goodFirstIssue)
                ],
                author: "vlnd0",
                updatedAgo: "1 day ago",
                comments: 1,
                commentItems: [
                    RepoIssueCommentItem(
                        id: "\(repository.id)-21-comment-1",
                        author: "openkubbo-bot",
                        body: "Tracking this for next extension release. Please share final assets and the publication checklist.",
                        updatedAgo: "20 hr. ago"
                    )
                ],
                isOpen: true,
                isMine: false
            ),
            RepoIssueItem(
                id: "\(repository.id)-17",
                number: 17,
                title: "Legacy parser fallback cleanup",
                body: "Remove obsolete parser fallback path after migration.\n\nContext:\n- New parser has been stable for multiple releases.\n- Legacy code increases maintenance and test matrix.\n\nAcceptance:\n- Remove fallback path.\n- Keep backward compatibility tests green.",
                labels: [RepoIssueLabel(id: "enhancement-17", title: "enhancement", kind: .enhancement)],
                author: "openkubbo-bot",
                updatedAgo: "2 days ago",
                comments: 2,
                commentItems: [
                    RepoIssueCommentItem(
                        id: "\(repository.id)-17-comment-1",
                        author: "tarikvillalobos",
                        body: "I started removing the fallback path. Before merging, we should validate older migrated projects one more time.",
                        updatedAgo: "1 day ago"
                    ),
                    RepoIssueCommentItem(
                        id: "\(repository.id)-17-comment-2",
                        author: "openkubbo-bot",
                        body: "CI passed for parser migration tests on latest run. Waiting for final manual verification.",
                        updatedAgo: "18 hr. ago"
                    )
                ],
                isOpen: false,
                isMine: false
            )
        ]
    }

    func loadIssueComments(
        for issue: RepoIssueItem,
        in repository: RepoItem
    ) async throws -> [RepoIssueCommentItem] {
        _ = repository
        return issue.commentItems
    }

    func createIssue(
        in repository: RepoItem,
        title: String,
        body: String?
    ) async throws -> RepoIssueItem {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentIssues = try await loadIssues(for: repository)
        let nextNumber = currentIssues.map(\.number).max() ?? 0

        return RepoIssueItem(
            id: "\(repository.id)-local-issue-\(UUID().uuidString)",
            number: nextNumber + 1,
            title: trimmedTitle,
            body: {
                guard let trimmedBody, !trimmedBody.isEmpty else {
                    return "No description provided."
                }
                return trimmedBody
            }(),
            labels: [],
            author: "you",
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
        _ = repository
        return RepoIssueCommentItem(
            id: "\(issue.id)-comment-\(UUID().uuidString)",
            author: "you",
            body: body,
            updatedAgo: "just now"
        )
    }

    func loadPullRequests(for repository: RepoItem) -> [RepoPullRequestItem] {
        [
            RepoPullRequestItem(
                id: "\(repository.id)-pr-91",
                number: 91,
                title: "Repository third panel",
                author: "tarikvillalobos",
                sourceBranch: "feature/repository-panel",
                targetBranch: repository.branch,
                updatedAgo: "9 min. ago",
                comments: 3,
                changedFiles: 8,
                commits: 6,
                additions: 312,
                deletions: 74,
                isOpen: true,
                isMerged: false,
                isMine: true
            ),
            RepoPullRequestItem(
                id: "\(repository.id)-pr-88",
                number: 88,
                title: "OAuth flow improvements",
                author: "tarikvillalobos",
                sourceBranch: "feat/github-oauth-ux",
                targetBranch: repository.branch,
                updatedAgo: "34 min. ago",
                comments: 1,
                changedFiles: 5,
                commits: 4,
                additions: 164,
                deletions: 29,
                isOpen: true,
                isMerged: false,
                isMine: true
            ),
            RepoPullRequestItem(
                id: "\(repository.id)-pr-84",
                number: 84,
                title: "Fix menu bar close behavior",
                author: "openkubbo-bot",
                sourceBranch: "fix/menu-close",
                targetBranch: repository.branch,
                updatedAgo: "2 hr. ago",
                comments: 0,
                changedFiles: 3,
                commits: 2,
                additions: 41,
                deletions: 16,
                isOpen: true,
                isMerged: false,
                isMine: false
            ),
            RepoPullRequestItem(
                id: "\(repository.id)-pr-80",
                number: 80,
                title: "Sidebar labels in English",
                author: "tarikvillalobos",
                sourceBranch: "chore/sidebar-en",
                targetBranch: repository.branch,
                updatedAgo: "1 day ago",
                comments: 2,
                changedFiles: 2,
                commits: 1,
                additions: 22,
                deletions: 9,
                isOpen: false,
                isMerged: true,
                isMine: true
            ),
            RepoPullRequestItem(
                id: "\(repository.id)-pr-78",
                number: 78,
                title: "Theme token cleanup",
                author: "teammate",
                sourceBranch: "refactor/theme-tokens",
                targetBranch: repository.branch,
                updatedAgo: "3 days ago",
                comments: 4,
                changedFiles: 11,
                commits: 7,
                additions: 288,
                deletions: 201,
                isOpen: false,
                isMerged: true,
                isMine: false
            )
        ]
    }

    func loadPullRequestCommits(
        for pullRequest: RepoPullRequestItem,
        in repository: RepoItem
    ) -> [RepoPullRequestCommitItem] {
        [
            RepoPullRequestCommitItem(
                id: "\(pullRequest.id)-c1",
                sha: "6d7f1b2",
                message: "feat(repository): add pull request overlay layout",
                author: pullRequest.author,
                committedAgo: "18 min. ago"
            ),
            RepoPullRequestCommitItem(
                id: "\(pullRequest.id)-c2",
                sha: "84a2fe9",
                message: "feat(repository): add create PR button in pull requests tab",
                author: pullRequest.author,
                committedAgo: "16 min. ago"
            ),
            RepoPullRequestCommitItem(
                id: "\(pullRequest.id)-c3",
                sha: "b13cd44",
                message: "feat(repository): add commit list details for selected pull request",
                author: pullRequest.author,
                committedAgo: "14 min. ago"
            ),
            RepoPullRequestCommitItem(
                id: "\(pullRequest.id)-c4",
                sha: "d21ab76",
                message: "style(repository): adjust badges and spacing in PR panel",
                author: repository.name.contains("tarik") ? "tarikvillalobos" : pullRequest.author,
                committedAgo: "11 min. ago"
            )
        ]
    }

    func loadBranches(for repository: RepoItem) async throws -> [RepoBranchItem] {
        [
            RepoBranchItem(
                id: "\(repository.id)-branch-\(repository.branch)",
                name: repository.branch,
                isDefault: true,
                isCurrent: true,
                aheadBy: 0,
                behindBy: 0,
                hasOpenPullRequest: false,
                updatedAgo: "1 min. ago"
            ),
            RepoBranchItem(
                id: "\(repository.id)-branch-feature-repository-panel",
                name: "feature/repository-panel",
                isDefault: false,
                isCurrent: false,
                aheadBy: 6,
                behindBy: 1,
                hasOpenPullRequest: true,
                updatedAgo: "9 min. ago"
            ),
            RepoBranchItem(
                id: "\(repository.id)-branch-feat-github-oauth-ux",
                name: "feat/github-oauth-ux",
                isDefault: false,
                isCurrent: false,
                aheadBy: 4,
                behindBy: 0,
                hasOpenPullRequest: true,
                updatedAgo: "34 min. ago"
            ),
            RepoBranchItem(
                id: "\(repository.id)-branch-feat-pr-creation-flow",
                name: "feat/pr-creation-flow",
                isDefault: false,
                isCurrent: false,
                aheadBy: 3,
                behindBy: 0,
                hasOpenPullRequest: false,
                updatedAgo: "12 min. ago"
            ),
            RepoBranchItem(
                id: "\(repository.id)-branch-chore-light-theme-polish",
                name: "chore/light-theme-polish",
                isDefault: false,
                isCurrent: false,
                aheadBy: 2,
                behindBy: 0,
                hasOpenPullRequest: false,
                updatedAgo: "53 min. ago"
            ),
            RepoBranchItem(
                id: "\(repository.id)-branch-fix-settings-spacing",
                name: "fix/settings-spacing",
                isDefault: false,
                isCurrent: false,
                aheadBy: 1,
                behindBy: 0,
                hasOpenPullRequest: false,
                updatedAgo: "2 hr. ago"
            ),
            RepoBranchItem(
                id: "\(repository.id)-branch-refactor-theme-store",
                name: "refactor/theme-store",
                isDefault: false,
                isCurrent: false,
                aheadBy: 0,
                behindBy: 0,
                hasOpenPullRequest: false,
                updatedAgo: "1 day ago"
            )
        ]
    }
}
