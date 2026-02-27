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

    func mockInfoItems(repoName: String, branch: String) -> [RepoDestinationInfoItem] {
        switch self {
        case .releases:
            return [
                RepoDestinationInfoItem(
                    id: "\(repoName)-release-162",
                    title: "v1.6.2",
                    subtitle: "UI adjustments and panel polish",
                    status: "Published",
                    metadata: "Published 2 days ago",
                    summary: "Includes light-mode contrast improvements, repository panel spacing fixes, and minor interaction polish.",
                    bulletPoints: [
                        "Improved contrast for cards and action buttons in light mode.",
                        "Adjusted modal border radius and spacing consistency.",
                        "Stabilized sidebar icon alignment in settings."
                    ],
                    trailingValue: "latest"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-release-161",
                    title: "v1.6.1",
                    subtitle: "GitHub integration polish",
                    status: "Published",
                    metadata: "Published 6 days ago",
                    summary: "Focus on GitHub device flow guidance and repository access ergonomics.",
                    bulletPoints: [
                        "Added direct device URL guidance in authentication flow.",
                        "Improved token visibility toggle behavior.",
                        "Refined repository list loading interactions."
                    ],
                    trailingValue: nil
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-release-160",
                    title: "v1.6.0",
                    subtitle: "Repository panel base",
                    status: "Published",
                    metadata: "Published 2 weeks ago",
                    summary: "First release of the repository panel and top-level navigation.",
                    bulletPoints: [
                        "Introduced repository list and contribution heatmap.",
                        "Added side panel actions for repository operations.",
                        "Set groundwork for issues, PRs, and branch overlays."
                    ],
                    trailingValue: nil
                )
            ]
        case .ciRuns:
            return [
                RepoDestinationInfoItem(
                    id: "\(repoName)-ci-macos",
                    title: "macOS Build",
                    subtitle: "Workflow #1242",
                    status: "Success",
                    metadata: "Ran 3 min. ago",
                    summary: "Build completed successfully for macOS target with all required checks passing.",
                    bulletPoints: [
                        "xcodebuild completed with no errors.",
                        "Swift compile and link stages completed.",
                        "Application signing completed for local run."
                    ],
                    trailingValue: "2m 14s"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-ci-lint",
                    title: "SwiftLint",
                    subtitle: "Workflow #1241",
                    status: "Success",
                    metadata: "Ran 8 min. ago",
                    summary: "Lint checks passed with no blocking violations.",
                    bulletPoints: [
                        "No new lint violations introduced.",
                        "Formatting rules consistent across repository files."
                    ],
                    trailingValue: "38s"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-ci-tests",
                    title: "Unit Tests",
                    subtitle: "Workflow #1240",
                    status: "Success",
                    metadata: "Ran 11 min. ago",
                    summary: "Test suite finished successfully.",
                    bulletPoints: [
                        "All target unit tests passed.",
                        "No flaky failures detected in this run."
                    ],
                    trailingValue: "4m 03s"
                )
            ]
        case .discussions:
            return [
                RepoDestinationInfoItem(
                    id: "\(repoName)-discussion-201",
                    title: "Feature request: Workspace presets",
                    subtitle: "Category: Ideas",
                    status: "Open",
                    metadata: "Last update 22 min. ago",
                    summary: "Proposal to allow reusable workspace templates for recurring task setups.",
                    bulletPoints: [
                        "Preset should include selected repositories.",
                        "Preset should include default filters and panel state.",
                        "Need export/import strategy for presets."
                    ],
                    trailingValue: "14 replies"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-discussion-197",
                    title: "Feedback: OAuth connect flow",
                    subtitle: "Category: Feedback",
                    status: "Open",
                    metadata: "Last update 2 hr. ago",
                    summary: "Users asked for clearer CTA to GitHub device page during login.",
                    bulletPoints: [
                        "Keep device URL visible and copyable.",
                        "Add explicit action sequence.",
                        "Clarify state while waiting for authorization."
                    ],
                    trailingValue: "9 replies"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-discussion-190",
                    title: "Question: Default branch handling",
                    subtitle: "Category: Q&A",
                    status: "Answered",
                    metadata: "Answered 1 day ago",
                    summary: "Clarifies how base branch is selected for PR creation.",
                    bulletPoints: [
                        "Base defaults to repository default branch.",
                        "Head must be ahead and non-default.",
                        "PR composer preselects first eligible branch."
                    ],
                    trailingValue: "Solved"
                )
            ]
        case .tags:
            return [
                RepoDestinationInfoItem(
                    id: "\(repoName)-tag-latest",
                    title: "latest",
                    subtitle: "Branch: \(branch)",
                    status: "Active",
                    metadata: "Updated 2 days ago",
                    summary: "Tracks the most recent stable release for quick environment setup.",
                    bulletPoints: [
                        "Used by deployment references.",
                        "Updated after release publication."
                    ],
                    trailingValue: "v1.6.2"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-tag-stable",
                    title: "stable",
                    subtitle: "Branch: \(branch)",
                    status: "Active",
                    metadata: "Updated 6 days ago",
                    summary: "Fallback tag used by integrations that avoid latest-edge changes.",
                    bulletPoints: [
                        "Pinned in compatibility environments.",
                        "Updated only after validation window."
                    ],
                    trailingValue: "v1.6.1"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-tag-preview",
                    title: "preview",
                    subtitle: "Branch: develop",
                    status: "Experimental",
                    metadata: "Updated 1 day ago",
                    summary: "Preview channel for upcoming changes before stable release.",
                    bulletPoints: [
                        "Can include breaking or incomplete adjustments.",
                        "Intended for testing and early feedback."
                    ],
                    trailingValue: nil
                )
            ]
        case .contributors:
            return [
                RepoDestinationInfoItem(
                    id: "\(repoName)-contrib-tarik",
                    title: "Tarik Villalobos",
                    subtitle: "Maintainer",
                    status: "Active",
                    metadata: "78 commits in last 30 days",
                    summary: "Primary maintainer across repository UI and GitHub integration workflows.",
                    bulletPoints: [
                        "Leads architecture and release planning.",
                        "Reviews and merges core feature branches.",
                        "Maintains repository settings and auth flows."
                    ],
                    trailingValue: "78"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-contrib-team",
                    title: "OpenKubbo Team",
                    subtitle: "Core",
                    status: "Active",
                    metadata: "31 commits in last 30 days",
                    summary: "Core team contributors focused on UI stability and infrastructure.",
                    bulletPoints: [
                        "Improves theme consistency and interaction feedback.",
                        "Maintains repository operation flows."
                    ],
                    trailingValue: "31"
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-contrib-community",
                    title: "Community Contributors",
                    subtitle: "External",
                    status: "Active",
                    metadata: "14 commits in last 30 days",
                    summary: "External collaborators contributing fixes and feature suggestions.",
                    bulletPoints: [
                        "Primarily UI polish and quality-of-life fixes.",
                        "Issues and discussion feedback support."
                    ],
                    trailingValue: "14"
                )
            ]
        case .openCommits:
            return [
                RepoDestinationInfoItem(
                    id: "\(repoName)-commit-1",
                    title: "feat: repository overlay interactions",
                    subtitle: "a1b2c3d • tarikvillalobos",
                    status: "Open",
                    metadata: "Committed 18 min. ago",
                    summary: "Adds improved transitions and selection behavior for nested repository overlays.",
                    bulletPoints: [
                        "Refined nested panel opening and closing transitions.",
                        "Improved hit-testing while overlays are active."
                    ],
                    trailingValue: branch
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-commit-2",
                    title: "style: improve light theme contrast",
                    subtitle: "d4e5f6g • tarikvillalobos",
                    status: "Open",
                    metadata: "Committed 46 min. ago",
                    summary: "Tweaks button and card contrast for better readability in light theme.",
                    bulletPoints: [
                        "Adjusted neutral backgrounds and border opacity.",
                        "Refined disabled state visibility."
                    ],
                    trailingValue: branch
                ),
                RepoDestinationInfoItem(
                    id: "\(repoName)-commit-3",
                    title: "fix: github device flow copy",
                    subtitle: "h7i8j9k • openkubbo-bot",
                    status: "Open",
                    metadata: "Committed 1 hr. ago",
                    summary: "Clarifies device flow instructions and visible URL guidance.",
                    bulletPoints: [
                        "Improved CTA wording for GitHub device page.",
                        "Added instruction ordering consistency."
                    ],
                    trailingValue: branch
                )
            ]
        default:
            return mockEntries(repoName: repoName, branch: branch).enumerated().map { index, entry in
                RepoDestinationInfoItem(
                    id: "\(repoName)-\(rawValue)-\(index)",
                    title: entry,
                    subtitle: helperText,
                    status: nil,
                    metadata: "Updated recently",
                    summary: entry,
                    bulletPoints: [],
                    trailingValue: nil
                )
            }
        }
    }
}

struct RepoDestinationInfoItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let status: String?
    let metadata: String
    let summary: String
    let bulletPoints: [String]
    let trailingValue: String?
}

struct RepoContributionDay: Equatable {
    let dateKey: String
    let count: Int
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

extension RepoItem {
    func updating(releases: Int) -> RepoItem {
        RepoItem(
            id: id,
            name: name,
            sshCloneURL: sshCloneURL,
            httpsCloneURL: httpsCloneURL,
            visibility: visibility,
            issues: issues,
            prs: prs,
            stars: stars,
            branch: branch,
            updatedAgo: updatedAgo,
            isPinned: isPinned,
            isWork: isWork,
            releases: max(0, releases),
            ciRuns: ciRuns,
            discussions: discussions,
            tags: tags,
            branches: branches,
            contributors: contributors,
            openCommits: openCommits
        )
    }

    func updating(ciRuns: Int) -> RepoItem {
        RepoItem(
            id: id,
            name: name,
            sshCloneURL: sshCloneURL,
            httpsCloneURL: httpsCloneURL,
            visibility: visibility,
            issues: issues,
            prs: prs,
            stars: stars,
            branch: branch,
            updatedAgo: updatedAgo,
            isPinned: isPinned,
            isWork: isWork,
            releases: releases,
            ciRuns: max(0, ciRuns),
            discussions: discussions,
            tags: tags,
            branches: branches,
            contributors: contributors,
            openCommits: openCommits
        )
    }

    func updating(openCommits: Int) -> RepoItem {
        RepoItem(
            id: id,
            name: name,
            sshCloneURL: sshCloneURL,
            httpsCloneURL: httpsCloneURL,
            visibility: visibility,
            issues: issues,
            prs: prs,
            stars: stars,
            branch: branch,
            updatedAgo: updatedAgo,
            isPinned: isPinned,
            isWork: isWork,
            releases: releases,
            ciRuns: ciRuns,
            discussions: discussions,
            tags: tags,
            branches: branches,
            contributors: contributors,
            openCommits: max(0, openCommits)
        )
    }

    func updating(tags: Int) -> RepoItem {
        RepoItem(
            id: id,
            name: name,
            sshCloneURL: sshCloneURL,
            httpsCloneURL: httpsCloneURL,
            visibility: visibility,
            issues: issues,
            prs: prs,
            stars: stars,
            branch: branch,
            updatedAgo: updatedAgo,
            isPinned: isPinned,
            isWork: isWork,
            releases: releases,
            ciRuns: ciRuns,
            discussions: discussions,
            tags: max(0, tags),
            branches: branches,
            contributors: contributors,
            openCommits: openCommits
        )
    }

    func updating(discussions: Int) -> RepoItem {
        RepoItem(
            id: id,
            name: name,
            sshCloneURL: sshCloneURL,
            httpsCloneURL: httpsCloneURL,
            visibility: visibility,
            issues: issues,
            prs: prs,
            stars: stars,
            branch: branch,
            updatedAgo: updatedAgo,
            isPinned: isPinned,
            isWork: isWork,
            releases: releases,
            ciRuns: ciRuns,
            discussions: max(0, discussions),
            tags: tags,
            branches: branches,
            contributors: contributors,
            openCommits: openCommits
        )
    }
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

struct RepoIssueCommentItem: Identifiable {
    let id: String
    let author: String
    let body: String
    let updatedAgo: String
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
    let commentItems: [RepoIssueCommentItem]
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
