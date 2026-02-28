import Foundation

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

    func fetchViewerLogin(accessToken: String) async throws -> String {
        let url = URL(string: "https://api.github.com/user")!
        let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
        let response: ViewerResponse = try await perform(request)
        return response.login
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

    func fetchContributionCalendar(accessToken: String) async throws -> GitHubContributionCalendar {
        let url = URL(string: "https://api.github.com/graphql")!
        let range = contributionRange()
        let query = """
        query ContributionCalendar($from: DateTime!, $to: DateTime!) {
          viewer {
            contributionsCollection(from: $from, to: $to) {
              contributionCalendar {
                weeks {
                  contributionDays {
                    date
                    contributionCount
                  }
                }
              }
            }
          }
        }
        """

        let request = try makeJSONRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            jsonBody: [
                "query": query,
                "variables": [
                    "from": range.from,
                    "to": range.to
                ]
            ]
        )

        let response: ContributionCalendarGraphQLResponse = try await perform(request)
        if let graphQLError = response.errors?.first?.message,
           !graphQLError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GitHubAPIError.api(graphQLError)
        }

        guard let weeks = response.data?.viewer.contributionsCollection.contributionCalendar.weeks else {
            throw GitHubAPIError.malformedResponse
        }

        let days = weeks.flatMap(\.contributionDays).map { day in
            GitHubContributionDay(
                dateKey: day.date,
                contributionCount: day.contributionCount
            )
        }

        return GitHubContributionCalendar(days: days)
    }

    func fetchBranches(accessToken: String, repositoryFullName: String) async throws -> [GitHubBranch] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var branches: [GitHubBranch] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/branches")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [BranchResponse] = try await perform(request)

            branches.append(
                contentsOf: response.map {
                    GitHubBranch(
                        name: $0.name,
                        isProtected: $0.isProtected,
                        commitSHA: $0.commit.sha
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return branches
    }

    func createBranch(
        accessToken: String,
        repositoryFullName: String,
        branchName: String,
        fromCommitSHA: String
    ) async throws -> GitHubBranch {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        let trimmedBranchName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSHA = fromCommitSHA.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBranchName.isEmpty else {
            throw GitHubAPIError.invalidParameters("Branch name is required.")
        }

        guard !trimmedSHA.isEmpty else {
            throw GitHubAPIError.invalidParameters("Base commit SHA is required.")
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/git/refs")!
        let request = try makeJSONRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            jsonBody: [
                "ref": "refs/heads/\(trimmedBranchName)",
                "sha": trimmedSHA
            ]
        )
        let response: GitReferenceResponse = try await perform(request)
        return GitHubBranch(
            name: normalizedBranchName(from: response.ref),
            isProtected: false,
            commitSHA: response.object.sha
        )
    }

    func fetchPullRequests(accessToken: String, repositoryFullName: String) async throws -> [GitHubPullRequest] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var pullRequests: [GitHubPullRequest] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/pulls")!
            components.queryItems = [
                URLQueryItem(name: "state", value: "all"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [PullRequestListResponse] = try await perform(request)

            pullRequests.append(
                contentsOf: response.compactMap { item in
                    guard let number = item.number,
                          let title = item.title,
                          !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }

                    return GitHubPullRequest(
                        id: "\(repositoryFullName)-pr-\(number)",
                        number: number,
                        title: title,
                        body: item.body ?? "",
                        authorLogin: item.user?.login ?? "unknown",
                        sourceBranch: item.head?.ref ?? "unknown",
                        targetBranch: item.base?.ref ?? "unknown",
                        updatedAt: {
                            guard let updatedAt = item.updatedAt else { return nil }
                            return iso8601Formatter.date(from: updatedAt)
                        }(),
                        comments: max(0, item.comments ?? 0),
                        changedFiles: max(0, item.changedFiles ?? 0),
                        commits: max(0, item.commits ?? 0),
                        additions: max(0, item.additions ?? 0),
                        deletions: max(0, item.deletions ?? 0),
                        isOpen: (item.state ?? "").lowercased() == "open",
                        isMerged: item.mergedAt != nil
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return pullRequests
    }

    func fetchPullRequestCommits(
        accessToken: String,
        repositoryFullName: String,
        pullRequestNumber: Int
    ) async throws -> [GitHubPullRequestCommit] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var commits: [GitHubPullRequestCommit] = []
        var page = 1

        while true {
            var components = URLComponents(
                string: "https://api.github.com/repos/\(owner)/\(repo)/pulls/\(pullRequestNumber)/commits"
            )!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [PullRequestCommitResponse] = try await perform(request)

            commits.append(
                contentsOf: response.compactMap { item in
                    guard let sha = item.sha,
                          let message = item.commit?.message,
                          !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return nil
                    }

                    return GitHubPullRequestCommit(
                        id: "\(repositoryFullName)-pr-\(pullRequestNumber)-commit-\(sha)",
                        sha: sha,
                        message: message,
                        authorLogin: item.author?.login ?? item.commit?.author?.name ?? "unknown",
                        committedAt: {
                            guard let date = item.commit?.author?.date else { return nil }
                            return iso8601Formatter.date(from: date)
                        }()
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return commits
    }

    func fetchRepositoryCommits(
        accessToken: String,
        repositoryFullName: String,
        branch: String
    ) async throws -> [GitHubRepositoryCommit] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        var commits: [GitHubRepositoryCommit] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/commits")!
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]
            if !trimmedBranch.isEmpty {
                queryItems.insert(URLQueryItem(name: "sha", value: trimmedBranch), at: 0)
            }
            components.queryItems = queryItems

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [RepositoryCommitResponse] = try await perform(request)

            commits.append(
                contentsOf: response.compactMap { item in
                    guard let sha = item.sha else {
                        return nil
                    }

                    let rawMessage = item.commit?.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !rawMessage.isEmpty else {
                        return nil
                    }

                    let message = rawMessage
                        .components(separatedBy: .newlines)
                        .first?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? rawMessage

                    let htmlURL: URL?
                    if let value = item.htmlURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        htmlURL = URL(string: value)
                    } else {
                        htmlURL = nil
                    }

                    return GitHubRepositoryCommit(
                        id: "\(repositoryFullName)-commit-\(sha)",
                        sha: sha,
                        message: message,
                        authorLogin: item.author?.login ?? item.commit?.author?.name ?? "unknown",
                        committedAt: parseISO8601(item.commit?.author?.date),
                        htmlURL: htmlURL
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return commits
    }

    func fetchRepositoryTags(
        accessToken: String,
        repositoryFullName: String
    ) async throws -> [GitHubRepositoryTag] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var tags: [GitHubRepositoryTag] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/tags")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [RepositoryTagResponse] = try await perform(request)

            tags.append(
                contentsOf: response.compactMap { item in
                    let trimmedName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let trimmedSHA = item.commit?.sha?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !trimmedName.isEmpty, !trimmedSHA.isEmpty else {
                        return nil
                    }

                    let tarballURL: URL?
                    if let value = item.tarballURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        tarballURL = URL(string: value)
                    } else {
                        tarballURL = nil
                    }

                    let zipballURL: URL?
                    if let value = item.zipballURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        zipballURL = URL(string: value)
                    } else {
                        zipballURL = nil
                    }

                    return GitHubRepositoryTag(
                        id: "\(repositoryFullName)-tag-\(trimmedName)",
                        name: trimmedName,
                        commitSHA: trimmedSHA,
                        tarballURL: tarballURL,
                        zipballURL: zipballURL
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return tags
    }

    func fetchRepositoryReleases(
        accessToken: String,
        repositoryFullName: String
    ) async throws -> [GitHubRepositoryRelease] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var releases: [GitHubRepositoryRelease] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [RepositoryReleaseResponse] = try await perform(request)

            releases.append(
                contentsOf: response.compactMap { item in
                    let trimmedTagName = item.tagName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !trimmedTagName.isEmpty else {
                        return nil
                    }

                    let trimmedName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let resolvedName = trimmedName.isEmpty ? trimmedTagName : trimmedName
                    let resolvedID = item.id.map(String.init) ?? trimmedTagName
                    let body = item.body ?? ""
                    let htmlURL: URL?
                    if let value = item.htmlURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        htmlURL = URL(string: value)
                    } else {
                        htmlURL = nil
                    }

                    return GitHubRepositoryRelease(
                        id: "\(repositoryFullName)-release-\(resolvedID)",
                        name: resolvedName,
                        tagName: trimmedTagName,
                        body: body,
                        authorLogin: item.author?.login ?? "unknown",
                        publishedAt: parseISO8601(item.publishedAt),
                        createdAt: parseISO8601(item.createdAt),
                        isDraft: item.draft ?? false,
                        isPrerelease: item.prerelease ?? false,
                        targetCommitish: item.targetCommitish,
                        htmlURL: htmlURL
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return releases.sorted { lhs, rhs in
            let lhsDate = lhs.publishedAt ?? lhs.createdAt ?? .distantPast
            let rhsDate = rhs.publishedAt ?? rhs.createdAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    func fetchRepositoryDiscussions(
        accessToken: String,
        repositoryFullName: String
    ) async throws -> [GitHubRepositoryDiscussion] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var discussions: [GitHubRepositoryDiscussion] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/discussions")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [RepositoryDiscussionResponse]
            do {
                response = try await perform(request)
            } catch GitHubAPIError.notFound {
                return []
            }

            discussions.append(
                contentsOf: response.compactMap { item in
                    guard let number = item.number else {
                        return nil
                    }

                    let trimmedTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !trimmedTitle.isEmpty else {
                        return nil
                    }

                    let resolvedID = item.id.map(String.init) ?? "\(number)"
                    let body = item.body ?? ""
                    let state = item.state?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "open"
                    let htmlURL: URL?
                    if let value = item.htmlURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        htmlURL = URL(string: value)
                    } else {
                        htmlURL = nil
                    }

                    return GitHubRepositoryDiscussion(
                        id: "\(repositoryFullName)-discussion-\(resolvedID)",
                        number: number,
                        title: trimmedTitle,
                        body: body,
                        categoryName: item.category?.name,
                        authorLogin: item.user?.login ?? "unknown",
                        state: state,
                        comments: max(0, item.comments ?? 0),
                        isAnswered: item.answerHTMLURL != nil || item.answeredAt != nil,
                        answeredAt: parseISO8601(item.answeredAt),
                        createdAt: parseISO8601(item.createdAt),
                        updatedAt: parseISO8601(item.updatedAt),
                        htmlURL: htmlURL
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return discussions.sorted { lhs, rhs in
            let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? .distantPast
            let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    func fetchRepositoryContributors(
        accessToken: String,
        repositoryFullName: String
    ) async throws -> [GitHubRepositoryContributor] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var contributors: [GitHubRepositoryContributor] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/contributors")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [RepositoryContributorResponse] = try await perform(request)

            contributors.append(
                contentsOf: response.compactMap { item in
                    let trimmedLogin = item.login?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !trimmedLogin.isEmpty else {
                        return nil
                    }

                    let resolvedID = item.id.map(String.init) ?? trimmedLogin
                    let contributorType = item.type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "User"
                    let avatarURL: URL?
                    if let value = item.avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        avatarURL = URL(string: value)
                    } else {
                        avatarURL = nil
                    }

                    let htmlURL: URL?
                    if let value = item.htmlURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !value.isEmpty {
                        htmlURL = URL(string: value)
                    } else {
                        htmlURL = nil
                    }

                    return GitHubRepositoryContributor(
                        id: "\(repositoryFullName)-contributor-\(resolvedID)",
                        login: trimmedLogin,
                        type: contributorType,
                        contributions: max(0, item.contributions ?? 0),
                        avatarURL: avatarURL,
                        htmlURL: htmlURL
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return contributors.sorted { lhs, rhs in
            if lhs.contributions != rhs.contributions {
                return lhs.contributions > rhs.contributions
            }
            return lhs.login.localizedCaseInsensitiveCompare(rhs.login) == .orderedAscending
        }
    }

    func fetchRepositoryMetricCounts(
        accessToken: String,
        repositoryFullName: String,
        branch: String
    ) async throws -> GitHubRepositoryMetricCounts {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let basePath = "https://api.github.com/repos/\(owner)/\(repo)"

        var commitsQueryItems: [URLQueryItem] = []
        if !trimmedBranch.isEmpty {
            commitsQueryItems.append(URLQueryItem(name: "sha", value: trimmedBranch))
        }

        let openCommits = try await fetchPaginatedCollectionCount(
            accessToken: accessToken,
            url: try makeCountURL(
                baseURLString: "\(basePath)/commits",
                extraQueryItems: commitsQueryItems
            )
        )
        let tags = try await fetchPaginatedCollectionCount(
            accessToken: accessToken,
            url: try makeCountURL(baseURLString: "\(basePath)/tags")
        )
        let releases = try await fetchPaginatedCollectionCount(
            accessToken: accessToken,
            url: try makeCountURL(baseURLString: "\(basePath)/releases")
        )
        let discussions = try await fetchPaginatedCollectionCount(
            accessToken: accessToken,
            url: try makeCountURL(baseURLString: "\(basePath)/discussions"),
            treatNotFoundAsZero: true
        )
        let contributors = try await fetchPaginatedCollectionCount(
            accessToken: accessToken,
            url: try makeCountURL(baseURLString: "\(basePath)/contributors")
        )

        return GitHubRepositoryMetricCounts(
            openCommits: max(0, openCommits),
            tags: max(0, tags),
            releases: max(0, releases),
            discussions: max(0, discussions),
            contributors: max(0, contributors)
        )
    }

    func fetchWorkflowRuns(accessToken: String, repositoryFullName: String) async throws -> [GitHubWorkflowRun] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var workflowRuns: [GitHubWorkflowRun] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/actions/runs")!
            components.queryItems = [
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: WorkflowRunsResponse = try await perform(request)

            workflowRuns.append(
                contentsOf: response.workflowRuns.compactMap { run in
                    guard let id = run.id,
                          let runNumber = run.runNumber else {
                        return nil
                    }

                    let name = run.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let resolvedName: String
                    if let name, !name.isEmpty {
                        resolvedName = name
                    } else if let displayTitle = run.displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                              !displayTitle.isEmpty {
                        resolvedName = displayTitle
                    } else {
                        resolvedName = "Workflow #\(runNumber)"
                    }

                    return GitHubWorkflowRun(
                        id: "\(repositoryFullName)-workflow-run-\(id)",
                        runNumber: runNumber,
                        name: resolvedName,
                        status: run.status ?? "unknown",
                        conclusion: run.conclusion,
                        event: run.event,
                        headBranch: run.headBranch,
                        headSHA: run.headSHA,
                        actorLogin: run.actor?.login,
                        createdAt: parseISO8601(run.createdAt),
                        updatedAt: parseISO8601(run.updatedAt),
                        startedAt: parseISO8601(run.runStartedAt),
                        htmlURL: {
                            guard let htmlURL = run.htmlURL else { return nil }
                            return URL(string: htmlURL)
                        }()
                    )
                }
            )

            if response.workflowRuns.count < 100 {
                break
            }

            page += 1
        }

        return workflowRuns.sorted { lhs, rhs in
            let leftDate = lhs.updatedAt ?? lhs.startedAt ?? lhs.createdAt ?? .distantPast
            let rightDate = rhs.updatedAt ?? rhs.startedAt ?? rhs.createdAt ?? .distantPast
            return leftDate > rightDate
        }
    }

    func fetchIssues(accessToken: String, repositoryFullName: String) async throws -> [GitHubIssue] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var issues: [GitHubIssue] = []
        var page = 1

        while true {
            var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/issues")!
            components.queryItems = [
                URLQueryItem(name: "state", value: "all"),
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "desc"),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [IssueListResponse] = try await perform(request)

            let pageIssues: [GitHubIssue] = response.compactMap { item in
                guard item.pullRequest == nil else {
                    return nil
                }

                return GitHubIssue(
                    id: "\(repositoryFullName)-issue-\(item.number)",
                    number: item.number,
                    title: item.title,
                    body: item.body ?? "",
                    authorLogin: item.user.login,
                    updatedAt: iso8601Formatter.date(from: item.updatedAt),
                    comments: max(0, item.comments),
                    isOpen: item.state.lowercased() == "open",
                    labels: item.labels.map {
                        GitHubIssueLabel(
                            id: "\(repositoryFullName)-issue-label-\($0.id)",
                            name: $0.name
                        )
                    }
                )
            }

            issues.append(contentsOf: pageIssues)

            if response.count < 100 {
                break
            }

            page += 1
        }

        return issues
    }

    func fetchIssueComments(
        accessToken: String,
        repositoryFullName: String,
        issueNumber: Int
    ) async throws -> [GitHubIssueComment] {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)
        var comments: [GitHubIssueComment] = []
        var page = 1

        while true {
            var components = URLComponents(
                string: "https://api.github.com/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments"
            )!
            components.queryItems = [
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "direction", value: "asc"),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "page", value: "\(page)")
            ]

            guard let url = components.url else {
                throw GitHubAPIError.malformedResponse
            }

            let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
            let response: [IssueCommentResponse] = try await perform(request)

            comments.append(
                contentsOf: response.map {
                    GitHubIssueComment(
                        id: "\(repositoryFullName)-issue-comment-\($0.id)",
                        authorLogin: $0.user.login,
                        body: $0.body,
                        updatedAt: iso8601Formatter.date(from: $0.updatedAt)
                    )
                }
            )

            if response.count < 100 {
                break
            }

            page += 1
        }

        return comments
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

    func createIssueComment(
        accessToken: String,
        repositoryFullName: String,
        issueNumber: Int,
        body: String
    ) async throws -> GitHubIssueComment {
        let (owner, repo) = try splitRepositoryFullName(repositoryFullName)

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            throw GitHubAPIError.invalidParameters("Comment body is required.")
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues/\(issueNumber)/comments")!
        let request = try makeJSONRequest(
            url: url,
            method: "POST",
            accessToken: accessToken,
            jsonBody: ["body": trimmedBody]
        )
        let response: IssueCommentResponse = try await perform(request)

        return GitHubIssueComment(
            id: "\(repositoryFullName)-issue-comment-\(response.id)",
            authorLogin: response.user.login,
            body: response.body,
            updatedAt: iso8601Formatter.date(from: response.updatedAt)
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

    private func makeCountURL(
        baseURLString: String,
        extraQueryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard var components = URLComponents(string: baseURLString) else {
            throw GitHubAPIError.malformedResponse
        }

        var queryItems = [URLQueryItem(name: "per_page", value: "1")]
        queryItems.append(contentsOf: extraQueryItems)
        components.queryItems = queryItems

        guard let url = components.url else {
            throw GitHubAPIError.malformedResponse
        }

        return url
    }

    private func fetchPaginatedCollectionCount(
        accessToken: String,
        url: URL,
        treatNotFoundAsZero: Bool = false
    ) async throws -> Int {
        let request = makeJSONRequest(url: url, method: "GET", accessToken: accessToken)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.malformedResponse
        }

        if httpResponse.statusCode == 404 && treatNotFoundAsZero {
            return 0
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw apiError(from: data, statusCode: httpResponse.statusCode)
        }

        if let countFromPagination = paginatedCountFromLinkHeader(httpResponse.value(forHTTPHeaderField: "Link")) {
            return max(0, countFromPagination)
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let array = object as? [Any] else {
            throw GitHubAPIError.malformedResponse
        }

        return max(0, array.count)
    }

    private func paginatedCountFromLinkHeader(_ linkHeader: String?) -> Int? {
        guard let linkHeader, !linkHeader.isEmpty else {
            return nil
        }

        let links = linkHeader.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let lastLink = links.first(where: { $0.contains("rel=\"last\"") }),
           let lastPage = pageNumber(from: lastLink) {
            return lastPage
        }

        if let nextLink = links.first(where: { $0.contains("rel=\"next\"") }),
           let nextPage = pageNumber(from: nextLink) {
            return nextPage
        }

        return nil
    }

    private func pageNumber(from link: String) -> Int? {
        guard let urlStart = link.firstIndex(of: "<"),
              let urlEnd = link.firstIndex(of: ">"),
              urlStart < urlEnd else {
            return nil
        }

        let rawURL = String(link[link.index(after: urlStart)..<urlEnd])
        guard let components = URLComponents(string: rawURL),
              let pageValue = components.queryItems?.first(where: { $0.name == "page" })?.value,
              let page = Int(pageValue) else {
            return nil
        }

        return max(0, page)
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

    private func normalizedBranchName(from gitRef: String) -> String {
        let prefix = "refs/heads/"
        if gitRef.hasPrefix(prefix) {
            return String(gitRef.dropFirst(prefix.count))
        }
        return gitRef
    }

    private func parseISO8601(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return iso8601Formatter.date(from: value)
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

    private func contributionRange() -> (from: String, to: String) {
        let now = Date()
        let fromDate = Calendar(identifier: .gregorian).date(byAdding: .year, value: -1, to: now) ?? now
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return (from: formatter.string(from: fromDate), to: formatter.string(from: now))
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

private struct ViewerResponse: Decodable {
    let login: String
}

private struct BranchResponse: Decodable {
    struct Commit: Decodable {
        let sha: String
    }

    let name: String
    let isProtected: Bool
    let commit: Commit

    enum CodingKeys: String, CodingKey {
        case name
        case isProtected = "protected"
        case commit
    }
}

private struct GitReferenceResponse: Decodable {
    struct GitObject: Decodable {
        let sha: String
    }

    let ref: String
    let object: GitObject
}

private struct IssueListResponse: Decodable {
    struct User: Decodable {
        let login: String
    }

    struct Label: Decodable {
        let id: Int64
        let name: String
    }

    struct PullRequestRef: Decodable {}

    let number: Int
    let title: String
    let body: String?
    let user: User
    let updatedAt: String
    let comments: Int
    let state: String
    let labels: [Label]
    let pullRequest: PullRequestRef?

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case body
        case user
        case updatedAt = "updated_at"
        case comments
        case state
        case labels
        case pullRequest = "pull_request"
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

private struct IssueCommentResponse: Decodable {
    struct User: Decodable {
        let login: String
    }

    let id: Int64
    let body: String
    let user: User
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case body
        case user
        case updatedAt = "updated_at"
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

private struct PullRequestListResponse: Decodable {
    struct User: Decodable {
        let login: String?
    }

    struct BranchRef: Decodable {
        let ref: String?
    }

    let number: Int?
    let title: String?
    let body: String?
    let user: User?
    let head: BranchRef?
    let base: BranchRef?
    let updatedAt: String?
    let comments: Int?
    let changedFiles: Int?
    let commits: Int?
    let additions: Int?
    let deletions: Int?
    let state: String?
    let mergedAt: String?

    enum CodingKeys: String, CodingKey {
        case number
        case title
        case body
        case user
        case head
        case base
        case updatedAt = "updated_at"
        case comments
        case changedFiles = "changed_files"
        case commits
        case additions
        case deletions
        case state
        case mergedAt = "merged_at"
    }
}

private struct PullRequestCommitResponse: Decodable {
    struct User: Decodable {
        let login: String?
    }

    struct Commit: Decodable {
        struct Author: Decodable {
            let name: String?
            let date: String?
        }

        let message: String?
        let author: Author?
    }

    let sha: String?
    let author: User?
    let commit: Commit?
}

private struct RepositoryCommitResponse: Decodable {
    struct User: Decodable {
        let login: String?
    }

    struct Commit: Decodable {
        struct Author: Decodable {
            let name: String?
            let date: String?
        }

        let message: String?
        let author: Author?
    }

    let sha: String?
    let author: User?
    let commit: Commit?
    let htmlURL: String?

    enum CodingKeys: String, CodingKey {
        case sha
        case author
        case commit
        case htmlURL = "html_url"
    }
}

private struct RepositoryTagResponse: Decodable {
    struct Commit: Decodable {
        let sha: String?
    }

    let name: String?
    let commit: Commit?
    let tarballURL: String?
    let zipballURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case commit
        case tarballURL = "tarball_url"
        case zipballURL = "zipball_url"
    }
}

private struct RepositoryReleaseResponse: Decodable {
    struct Author: Decodable {
        let login: String?
    }

    let id: Int64?
    let name: String?
    let tagName: String?
    let body: String?
    let draft: Bool?
    let prerelease: Bool?
    let targetCommitish: String?
    let publishedAt: String?
    let createdAt: String?
    let htmlURL: String?
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagName = "tag_name"
        case body
        case draft
        case prerelease
        case targetCommitish = "target_commitish"
        case publishedAt = "published_at"
        case createdAt = "created_at"
        case htmlURL = "html_url"
        case author
    }
}

private struct RepositoryDiscussionResponse: Decodable {
    struct User: Decodable {
        let login: String?
    }

    struct Category: Decodable {
        let name: String?
    }

    let id: Int64?
    let number: Int?
    let title: String?
    let body: String?
    let state: String?
    let comments: Int?
    let answeredAt: String?
    let answerHTMLURL: String?
    let createdAt: String?
    let updatedAt: String?
    let htmlURL: String?
    let user: User?
    let category: Category?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case body
        case state
        case comments
        case answeredAt = "answered_at"
        case answerHTMLURL = "answer_html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlURL = "html_url"
        case user
        case category
    }
}

private struct RepositoryContributorResponse: Decodable {
    let id: Int64?
    let login: String?
    let type: String?
    let contributions: Int?
    let avatarURL: String?
    let htmlURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case type
        case contributions
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
    }
}

private struct WorkflowRunsResponse: Decodable {
    let workflowRuns: [WorkflowRunResponse]

    enum CodingKeys: String, CodingKey {
        case workflowRuns = "workflow_runs"
    }
}

private struct WorkflowRunResponse: Decodable {
    struct Actor: Decodable {
        let login: String?
    }

    let id: Int64?
    let runNumber: Int?
    let name: String?
    let displayTitle: String?
    let status: String?
    let conclusion: String?
    let event: String?
    let headBranch: String?
    let headSHA: String?
    let actor: Actor?
    let createdAt: String?
    let updatedAt: String?
    let runStartedAt: String?
    let htmlURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case runNumber = "run_number"
        case name
        case displayTitle = "display_title"
        case status
        case conclusion
        case event
        case headBranch = "head_branch"
        case headSHA = "head_sha"
        case actor
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runStartedAt = "run_started_at"
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

private struct ContributionCalendarGraphQLResponse: Decodable {
    struct DataPayload: Decodable {
        struct Viewer: Decodable {
            struct ContributionsCollection: Decodable {
                struct ContributionCalendar: Decodable {
                    struct Week: Decodable {
                        struct Day: Decodable {
                            let date: String
                            let contributionCount: Int
                        }

                        let contributionDays: [Day]
                    }

                    let weeks: [Week]
                }

                let contributionCalendar: ContributionCalendar
            }

            let contributionsCollection: ContributionsCollection
        }

        let viewer: Viewer
    }

    struct GraphQLError: Decodable {
        let message: String
    }

    let data: DataPayload?
    let errors: [GraphQLError]?
}

private struct APIErrorResponse: Decodable {
    let message: String?
}
