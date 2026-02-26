import Foundation

struct GitHubAuthenticatedUser: Equatable {
    let login: String
    let name: String?
    let avatarURL: URL?
}

struct GitHubDeviceCode {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int
}

enum GitHubOAuthError: LocalizedError {
    case invalidClientID
    case timeout
    case cancelled
    case malformedResponse
    case accessDenied
    case expiredToken
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidClientID:
            return "GitHub OAuth Client ID is invalid."
        case .timeout:
            return "GitHub authorization timed out."
        case .cancelled:
            return "GitHub authorization was cancelled."
        case .malformedResponse:
            return "Unexpected response from GitHub."
        case .accessDenied:
            return "GitHub authorization was denied."
        case .expiredToken:
            return "The GitHub device code expired. Please try again."
        case .unknown(let message):
            return message
        }
    }
}

protocol GitHubOAuthServicing {
    func requestDeviceCode(clientID: String, scope: String) async throws -> GitHubDeviceCode
    func pollAccessToken(clientID: String, deviceCode: String, interval: Int, expiresIn: Int) async throws -> String
    func fetchViewer(accessToken: String) async throws -> GitHubAuthenticatedUser
}

protocol GitHubTokenStoring {
    func token() -> String?
    func save(token: String)
    func clear()
}

struct GitHubRepository: Identifiable, Equatable {
    let id: String
    let name: String
    let fullName: String
    let ownerLogin: String
    let sshCloneURL: String
    let httpsCloneURL: String
    let isPrivate: Bool
    let defaultBranch: String
    let openIssuesCount: Int
    let stargazersCount: Int
    let updatedAt: Date?
    let htmlURL: URL?
}

struct GitHubIssueSummary: Equatable {
    let number: Int
    let title: String
    let htmlURL: URL?
}

struct GitHubPullRequestSummary: Equatable {
    let number: Int
    let title: String
    let htmlURL: URL?
}

struct GitHubPullRequest: Equatable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let authorLogin: String
    let sourceBranch: String
    let targetBranch: String
    let updatedAt: Date?
    let comments: Int
    let changedFiles: Int
    let commits: Int
    let additions: Int
    let deletions: Int
    let isOpen: Bool
    let isMerged: Bool
}

struct GitHubPullRequestCommit: Equatable {
    let id: String
    let sha: String
    let message: String
    let authorLogin: String
    let committedAt: Date?
}

struct GitHubWorkflowRun: Equatable {
    let id: String
    let runNumber: Int
    let name: String
    let status: String
    let conclusion: String?
    let event: String?
    let headBranch: String?
    let headSHA: String?
    let actorLogin: String?
    let createdAt: Date?
    let updatedAt: Date?
    let startedAt: Date?
    let htmlURL: URL?
}

struct GitHubCommitSummary: Equatable {
    let sha: String
    let message: String
    let htmlURL: URL?
}

struct GitHubIssueLabel: Equatable {
    let id: String
    let name: String
}

struct GitHubIssue: Equatable {
    let id: String
    let number: Int
    let title: String
    let body: String
    let authorLogin: String
    let updatedAt: Date?
    let comments: Int
    let isOpen: Bool
    let labels: [GitHubIssueLabel]
}

struct GitHubIssueComment: Equatable {
    let id: String
    let authorLogin: String
    let body: String
    let updatedAt: Date?
}

struct GitHubBranch: Equatable {
    let name: String
    let isProtected: Bool
    let commitSHA: String
}

struct GitHubContributionDay: Equatable {
    let dateKey: String
    let contributionCount: Int
}

struct GitHubContributionCalendar: Equatable {
    let days: [GitHubContributionDay]
}

enum GitHubAPIError: LocalizedError {
    case invalidRepositoryFormat
    case invalidFilePath
    case invalidParameters(String)
    case malformedResponse
    case unauthorized
    case notFound
    case forbidden(String)
    case api(String)
    case unknownStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryFormat:
            return "Repository must be in owner/repo format."
        case .invalidFilePath:
            return "File path is invalid."
        case .invalidParameters(let message):
            return message
        case .malformedResponse:
            return "Unexpected response from GitHub."
        case .unauthorized:
            return "GitHub authorization expired. Please connect again."
        case .notFound:
            return "GitHub resource not found."
        case .forbidden(let message):
            return message
        case .api(let message):
            return message
        case .unknownStatus(let statusCode):
            return "GitHub request failed with status \(statusCode)."
        }
    }
}

protocol GitHubAPIServicing {
    func fetchViewerLogin(accessToken: String) async throws -> String
    func fetchRepositories(accessToken: String) async throws -> [GitHubRepository]
    func fetchContributionCalendar(accessToken: String) async throws -> GitHubContributionCalendar
    func fetchBranches(accessToken: String, repositoryFullName: String) async throws -> [GitHubBranch]
    func createBranch(
        accessToken: String,
        repositoryFullName: String,
        branchName: String,
        fromCommitSHA: String
    ) async throws -> GitHubBranch
    func fetchPullRequests(accessToken: String, repositoryFullName: String) async throws -> [GitHubPullRequest]
    func fetchPullRequestCommits(
        accessToken: String,
        repositoryFullName: String,
        pullRequestNumber: Int
    ) async throws -> [GitHubPullRequestCommit]
    func fetchWorkflowRuns(accessToken: String, repositoryFullName: String) async throws -> [GitHubWorkflowRun]
    func fetchIssues(accessToken: String, repositoryFullName: String) async throws -> [GitHubIssue]
    func fetchIssueComments(
        accessToken: String,
        repositoryFullName: String,
        issueNumber: Int
    ) async throws -> [GitHubIssueComment]
    func createIssue(
        accessToken: String,
        repositoryFullName: String,
        title: String,
        body: String?
    ) async throws -> GitHubIssueSummary
    func createIssueComment(
        accessToken: String,
        repositoryFullName: String,
        issueNumber: Int,
        body: String
    ) async throws -> GitHubIssueComment
    func createPullRequest(
        accessToken: String,
        repositoryFullName: String,
        title: String,
        body: String?,
        head: String,
        base: String
    ) async throws -> GitHubPullRequestSummary
    func commitFile(
        accessToken: String,
        repositoryFullName: String,
        path: String,
        branch: String,
        message: String,
        content: String
    ) async throws -> GitHubCommitSummary
}
