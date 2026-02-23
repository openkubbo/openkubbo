import Foundation

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

struct GitHubCommitSummary: Equatable {
    let sha: String
    let message: String
    let htmlURL: URL?
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
    func fetchRepositories(accessToken: String) async throws -> [GitHubRepository]
    func createIssue(
        accessToken: String,
        repositoryFullName: String,
        title: String,
        body: String?
    ) async throws -> GitHubIssueSummary
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

final class GitHubAPIService: GitHubAPIServicing {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let userAgent: String
    private let apiVersion: String
    private let iso8601Formatter = ISO8601DateFormatter()

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        userAgent: String = "OpenKubbo",
        apiVersion: String = "2022-11-28"
    ) {
        self.session = session
        self.decoder = decoder
        self.userAgent = userAgent
        self.apiVersion = apiVersion
    }

    func fetchRepositories(accessToken: String) async throws -> [GitHubRepository] {
        var repositories: [GitHubRepository] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/user/repos")!
            components.queryItems = [
                URLQueryItem(name: "visibility", value: "all"),
                URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [RepositoryResponse] = try await perform(request)

            repositories.append(
                contentsOf: response.map {
                    GitHubRepository(
                        id: $0.fullName,
                        name: $0.name,
                        fullName: $0.fullName,
                        ownerLogin: $0.owner.login,
                        sshCloneURL: $0.sshCloneURL,
                        httpsCloneURL: $0.httpsCloneURL,
                        isPrivate: $0.isPrivate,
                        defaultBranch: $0.defaultBranch,
                        openIssuesCount: $0.openIssuesCount,
                        stargazersCount: $0.stargazersCount,
                        updatedAt: iso8601Formatter.date(from: $0.updatedAt),
                        htmlURL: URL(string: $0.htmlURL)
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return repositories
    }

    func createIssue(
        accessToken: String,
        repositoryFullName: String,
        title: String,
        body: String?
    ) async throws -> GitHubIssueSummary {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw GitHubAPIError.invalidParameters("Issue title is required.")
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues")!
        var payload: [String: Any] = ["title": trimmedTitle]
        if let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["body"] = body
        }

        let request = try makeJSONRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            jsonBody: payload
        )
        let response: IssueResponse = try await perform(request)

        return GitHubIssueSummary(
            number: response.number,
            title: response.title,
            htmlURL: URL(string: response.htmlURL)
        )
    }

    func createPullRequest(
        accessToken: String,
        repositoryFullName: String,
        title: String,
        body: String?,
        head: String,
        base: String
    ) async throws -> GitHubPullRequestSummary {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHead = head.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            throw GitHubAPIError.invalidParameters("Pull request title is required.")
        }
        guard !trimmedHead.isEmpty else {
            throw GitHubAPIError.invalidParameters("Head branch is required.")
        }
        guard !trimmedBase.isEmpty else {
            throw GitHubAPIError.invalidParameters("Base branch is required.")
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/pulls")!
        var payload: [String: Any] = [
            "title": trimmedTitle,
            "head": trimmedHead,
            "base": trimmedBase
        ]
        if let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["body"] = body
        }

        let request = try makeJSONRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            jsonBody: payload
        )
        let response: PullRequestResponse = try await perform(request)

        return GitHubPullRequestSummary(
            number: response.number,
            title: response.title,
            htmlURL: URL(string: response.htmlURL)
        )
    }

    func commitFile(
        accessToken: String,
        repositoryFullName: String,
        path: String,
        branch: String,
        message: String,
        content: String
    ) async throws -> GitHubCommitSummary {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        let encodedPath = try encodePath(path)

        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBranch.isEmpty else {
            throw GitHubAPIError.invalidParameters("Commit branch is required.")
        }
        guard !trimmedMessage.isEmpty else {
            throw GitHubAPIError.invalidParameters("Commit message is required.")
        }
        guard !content.isEmpty else {
            throw GitHubAPIError.invalidParameters("File content is required.")
        }

        let existingSHA = try await fetchExistingFileSHA(
            accessToken: accessToken,
            owner: owner,
            repo: repo,
            encodedPath: encodedPath,
            branch: trimmedBranch
        )

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encodedPath)")!
        var payload: [String: Any] = [
            "message": trimmedMessage,
            "content": Data(content.utf8).base64EncodedString(),
            "branch": trimmedBranch
        ]
        if let existingSHA {
            payload["sha"] = existingSHA
        }

        let request = try makeJSONRequest(
            url: url,
            method: "PUT",
            accessToken: accessToken,
            jsonBody: payload
        )
        let response: CommitFileResponse = try await perform(request)

        return GitHubCommitSummary(
            sha: response.commit.sha,
            message: response.commit.message,
            htmlURL: URL(string: response.commit.htmlURL ?? "")
        )
    }

    private func fetchExistingFileSHA(
        accessToken: String,
        owner: String,
        repo: String,
        encodedPath: String,
        branch: String
    ) async throws -> String? {
        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(encodedPath)")!
        components.queryItems = [URLQueryItem(name: "ref", value: branch)]

        guard let url = components.url else {
            throw GitHubAPIError.malformedResponse
        }

        let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.malformedResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let fileResponse = try decoder.decode(FileContentResponse.self, from: data)
            return fileResponse.sha
        case 404:
            return nil
        default:
            throw apiError(from: data, statusCode: httpResponse.statusCode)
        }
    }

    private func splitRepositoryFullName(_ value: String) throws -> (String, String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: "/").map(String.init)

        guard components.count == 2,
              !components[0].isEmpty,
              !components[1].isEmpty
        else {
            throw GitHubAPIError.invalidRepositoryFormat
        }

        return (components[0], components[1])
    }

    private func encodePath(_ path: String) throws -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        guard !normalized.isEmpty else {
            throw GitHubAPIError.invalidFilePath
        }

        return normalized
            .split(separator: "/")
            .map { segment in
                String(segment).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
            }
            .joined(separator: "/")
    }

    private func makeJSONRequest(url: URL, method: String, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func makeJSONRequest(
        url: URL,
        method: String,
        accessToken: String,
        jsonBody: [String: Any]
    ) throws -> URLRequest {
        var request = makeJSONRequest(url: url, method: method, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.malformedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw apiError(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.malformedResponse
        }
    }

    private func apiError(from data: Data, statusCode: Int) -> GitHubAPIError {
        let apiMessage = (try? decoder.decode(APIErrorResponse.self, from: data))?.message

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden(apiMessage ?? "Access to this GitHub resource was denied.")
        case 404:
            return .notFound
        default:
            if let apiMessage, !apiMessage.isEmpty {
                return .api(apiMessage)
            }
            return .unknownStatus(statusCode)
        }
    }
}

private struct RepositoryResponse: Decodable {
    struct Owner: Decodable {
        let login: String
    }

    let name: String
    let fullName: String
    let owner: Owner
    let sshCloneURL: String
    let httpsCloneURL: String
    let isPrivate: Bool
    let defaultBranch: String
    let openIssuesCount: Int
    let stargazersCount: Int
    let updatedAt: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case owner
        case sshCloneURL = "ssh_url"
        case httpsCloneURL = "clone_url"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case openIssuesCount = "open_issues_count"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
        case htmlURL = "html_url"
    }
}

private struct IssueResponse: Decodable {
    let number: Int
    let title: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case htmlURL = "html_url"
    }
}

private struct PullRequestResponse: Decodable {
    let number: Int
    let title: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case htmlURL = "html_url"
    }
}

private struct FileContentResponse: Decodable {
    let sha: String
}

private struct CommitFileResponse: Decodable {
    struct Commit: Decodable {
        let sha: String
        let message: String
        let htmlURL: String?

        enum CodingKeys: String, CodingKey {
            case sha
            case message
            case htmlURL = "html_url"
        }
    }

    let commit: Commit
}

private struct APIErrorResponse: Decodable {
    let message: String?
}
