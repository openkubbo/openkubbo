import Foundation

enum RepoVisibility: Equatable {
    case openSource
    case `private`

    var label: String {
        switch self {
        case .openSource:
            return "Open source"
        case .private:
            return "Private"
        }
    }

    var icon: String {
        switch self {
        case .openSource:
            return "lock.open"
        case .private:
            return "lock"
        }
    }
}

enum RepoFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pinned = "Pinned"
    case work = "Work"

    var id: String { rawValue }
}

enum RepoDetailDestination: String, Identifiable {
    case switchWorktree
    case issues
    case pullRequests
    case releases
    case ciRuns
    case discussions
    case tags
    case branches
    case contributors
    case openCommits

    var id: String { rawValue }

    var title: String {
        switch self {
        case .switchWorktree:
            return "Switch Worktree"
        case .issues:
            return "Issues"
        case .pullRequests:
            return "Pull Requests"
        case .releases:
            return "Releases"
        case .ciRuns:
            return "CI Runs"
        case .discussions:
            return "Discussions"
        case .tags:
            return "Tags"
        case .branches:
            return "Branches"
        case .contributors:
            return "Contributors"
        case .openCommits:
            return "Open Commits"
        }
    }

    var icon: String {
        switch self {
        case .switchWorktree:
            return "arrow.left.arrow.right"
        case .issues:
            return "exclamationmark.circle"
        case .pullRequests:
            return "arrow.triangle.pull"
        case .releases:
            return "shippingbox"
        case .ciRuns:
            return "bolt"
        case .discussions:
            return "bubble.left"
        case .tags:
            return "tag"
        case .branches:
            return "arrow.triangle.branch"
        case .contributors:
            return "person.2"
        case .openCommits:
            return "clock.arrow.circlepath"
        }
    }

    var helperText: String {
        switch self {
        case .switchWorktree:
            return "Choose a worktree"
        case .issues:
            return "Issue overview"
        case .pullRequests:
            return "Pull request overview"
        case .releases:
            return "Release summary"
        case .ciRuns:
            return "Recent CI activity"
        case .discussions:
            return "Discussion overview"
        case .tags:
            return "Tag summary"
        case .branches:
            return "Branch summary"
        case .contributors:
            return "Contributors overview"
        case .openCommits:
            return "Open commit activity"
        }
    }

    func mockEntries(repoName: String, branch: String) -> [String] {
        switch self {
        case .switchWorktree:
            return [
                "Use \(repoName) • \(branch) (active)",
                "Use \(repoName) • develop",
                "Create new worktree"
            ]
        case .issues:
            return [
                "Issue #128 - Improve onboarding copy",
                "Issue #127 - Adjust light mode contrast",
                "Issue #122 - Add repository interactions"
            ]
        case .pullRequests:
            return [
                "PR #91 - Repository third panel",
                "PR #88 - OAuth flow improvements",
                "PR #83 - Sidebar text updates"
            ]
        case .releases:
            return [
                "v1.6.2 - UI adjustments",
                "v1.6.1 - GitHub integration polish",
                "v1.6.0 - Repository panel"
            ]
        case .ciRuns:
            return [
                "macOS Build - Success",
                "SwiftLint - Success",
                "Unit Tests - Success"
            ]
        case .discussions:
            return [
                "Feature request: Workspace presets",
                "Feedback: OAuth connect flow",
                "Question: Repository default branch"
            ]
        case .tags:
            return ["latest", "stable", "preview"]
        case .branches:
            return [branch, "develop", "feature/repository-panel"]
        case .contributors:
            return ["Tarik Villalobos", "OpenKubbo Team", "Community Contributors"]
        case .openCommits:
            return [
                "feat: repository overlay interactions",
                "style: improve light theme contrast",
                "fix: github device flow copy"
            ]
        }
    }
}

struct RepoItem: Identifiable, Equatable {
    let id: String
    let name: String
    let sshCloneURL: String?
    let httpsCloneURL: String?
    let visibility: RepoVisibility
    let issues: Int
    let prs: Int
    let stars: Int
    let branch: String
    let updatedAgo: String
    let isPinned: Bool
    let isWork: Bool
    let releases: Int
    let ciRuns: Int
    let discussions: Int
    let tags: Int
    let branches: Int
    let contributors: Int
    let openCommits: Int
}

struct RepoMetric: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: Int?
    let destination: RepoDetailDestination
}

enum RepoIssuesScope: String, CaseIterable, Identifiable {
    case all = "All"
    case mine = "Mine"
    case open = "Open"
    case closed = "Closed"

    var id: String { rawValue }
}

enum RepoPullRequestsScope: String, CaseIterable, Identifiable {
    case all = "All"
    case mine = "Mine"
    case open = "Open"
    case merged = "Merged"

    var id: String { rawValue }
}

enum RepoIssueLabelKind {
    case bug
    case enhancement
    case helpWanted
    case goodFirstIssue
}

struct RepoIssueLabel: Identifiable {
    let id: String
    let title: String
    let kind: RepoIssueLabelKind
}

struct RepoIssueItem: Identifiable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let labels: [RepoIssueLabel]
    let author: String
    let updatedAgo: String
    let comments: Int
    let isOpen: Bool
    let isMine: Bool
}

struct RepoPullRequestItem: Identifiable {
    let id: String
    let number: Int
    let title: String
    let author: String
    let sourceBranch: String
    let targetBranch: String
    let updatedAgo: String
    let comments: Int
    let changedFiles: Int
    let commits: Int
    let additions: Int
    let deletions: Int
    let isOpen: Bool
    let isMerged: Bool
    let isMine: Bool
}

struct RepoPullRequestCommitItem: Identifiable {
    let id: String
    let sha: String
    let message: String
    let author: String
    let committedAgo: String
}

struct RepoBranchItem: Identifiable {
    let id: String
    let name: String
    let isDefault: Bool
    let isCurrent: Bool
    let aheadBy: Int
    let behindBy: Int
    let hasOpenPullRequest: Bool
    let updatedAgo: String

    func canOpenPullRequest(baseBranch: String) -> Bool {
        if name == baseBranch {
            return false
        }
        if isDefault {
            return false
        }
        if aheadBy <= 0 {
            return false
        }
        return !hasOpenPullRequest
    }
}
