import Foundation

protocol RepositoryDataProviding {
    func loadRepositories() async throws -> [RepoItem]
    func loadIssues(for repository: RepoItem) -> [RepoIssueItem]
}

struct MockRepositoryDataProvider: RepositoryDataProviding {
    func loadRepositories() async throws -> [RepoItem] {
        [
            RepoItem(
                id: "tarikvillalobos/postme",
                name: "tarikvillalobos/postme",
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

    func loadIssues(for repository: RepoItem) -> [RepoIssueItem] {
        [
            RepoIssueItem(
                id: "\(repository.id)-26",
                number: 26,
                title: "Refactor: Glass effect performance",
                labels: [RepoIssueLabel(id: "enhancement-26", title: "enhancement", kind: .enhancement)],
                author: "tarikvillalobos",
                updatedAgo: "20 min. ago",
                comments: 0,
                isOpen: true,
                isMine: true
            ),
            RepoIssueItem(
                id: "\(repository.id)-25",
                number: 25,
                title: "Chat UI doesn't disappear if disabled in settings.",
                labels: [RepoIssueLabel(id: "bug-25", title: "bug", kind: .bug)],
                author: "tarikvillalobos",
                updatedAgo: "21 min. ago",
                comments: 0,
                isOpen: true,
                isMine: true
            ),
            RepoIssueItem(
                id: "\(repository.id)-24",
                number: 24,
                title: "Build fails on Windows: 'rm' command not recognized in clean scripts",
                labels: [
                    RepoIssueLabel(id: "bug-24", title: "bug", kind: .bug),
                    RepoIssueLabel(id: "help-24", title: "help wanted", kind: .helpWanted),
                    RepoIssueLabel(id: "good-24", title: "good first issue", kind: .goodFirstIssue)
                ],
                author: "Ehtz",
                updatedAgo: "1 hr. ago",
                comments: 1,
                isOpen: true,
                isMine: false
            ),
            RepoIssueItem(
                id: "\(repository.id)-21",
                number: 21,
                title: "Mozila extension",
                labels: [
                    RepoIssueLabel(id: "help-21", title: "help wanted", kind: .helpWanted),
                    RepoIssueLabel(id: "good-21", title: "good first issue", kind: .goodFirstIssue)
                ],
                author: "vlnd0",
                updatedAgo: "1 day ago",
                comments: 1,
                isOpen: true,
                isMine: false
            ),
            RepoIssueItem(
                id: "\(repository.id)-17",
                number: 17,
                title: "Legacy parser fallback cleanup",
                labels: [RepoIssueLabel(id: "enhancement-17", title: "enhancement", kind: .enhancement)],
                author: "openkubbo-bot",
                updatedAgo: "2 days ago",
                comments: 2,
                isOpen: false,
                isMine: false
            )
        ]
    }
}
