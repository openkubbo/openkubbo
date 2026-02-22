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

final class GitHubOAuthService: GitHubOAuthServicing {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let userAgent: String

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        userAgent: String = "OpenKubbo"
    ) {
        self.session = session
        self.decoder = decoder
        self.userAgent = userAgent
    }

    func requestDeviceCode(clientID: String, scope: String = "read:user user:email") async throws -> GitHubDeviceCode {
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GitHubOAuthError.invalidClientID
        }

        let url = URL(string: "https://github.com/login/device/code")!
        let request = makeFormRequest(
            url: url,
            body: [
                "client_id": clientID,
                "scope": scope
            ]
        )

        let response: DeviceCodeResponse = try await perform(request)

        return GitHubDeviceCode(
            deviceCode: response.deviceCode,
            userCode: response.userCode,
            verificationURI: response.verificationURI,
            expiresIn: response.expiresIn,
            interval: max(response.interval, 1)
        )
    }

    func pollAccessToken(clientID: String, deviceCode: String, interval: Int, expiresIn: Int) async throws -> String {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        var pollingInterval = max(interval, 1)

        while Date() < deadline {
            try Task.checkCancellation()

            let accessTokenResponse = try await requestAccessToken(clientID: clientID, deviceCode: deviceCode)

            if let accessToken = accessTokenResponse.accessToken {
                return accessToken
            }

            switch accessTokenResponse.error {
            case "authorization_pending":
                try await Task.sleep(nanoseconds: UInt64(pollingInterval) * 1_000_000_000)
            case "slow_down":
                pollingInterval += 5
                try await Task.sleep(nanoseconds: UInt64(pollingInterval) * 1_000_000_000)
            case "expired_token":
                throw GitHubOAuthError.expiredToken
            case "access_denied":
                throw GitHubOAuthError.accessDenied
            case "invalid_client":
                throw GitHubOAuthError.invalidClientID
            case let errorCode?:
                throw GitHubOAuthError.unknown(accessTokenResponse.errorDescription ?? errorCode)
            case nil:
                throw GitHubOAuthError.malformedResponse
            }
        }

        throw GitHubOAuthError.timeout
    }

    func fetchViewer(accessToken: String) async throws -> GitHubAuthenticatedUser {
        let url = URL(string: "https://api.github.com/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let userResponse: UserResponse = try await perform(request)

        return GitHubAuthenticatedUser(
            login: userResponse.login,
            name: userResponse.name,
            avatarURL: URL(string: userResponse.avatarURL)
        )
    }

    private func requestAccessToken(clientID: String, deviceCode: String) async throws -> AccessTokenResponse {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        let request = makeFormRequest(
            url: url,
            body: [
                "client_id": clientID,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            ]
        )

        return try await perform(request)
    }

    private func makeFormRequest(url: URL, body: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
            .data(using: .utf8)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubOAuthError.malformedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data), let message = apiError.errorDescription {
                throw GitHubOAuthError.unknown(message)
            }

            throw GitHubOAuthError.unknown("GitHub request failed with status \(httpResponse.statusCode).")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubOAuthError.malformedResponse
        }
    }
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationURI: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

private struct AccessTokenResponse: Decodable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
        case errorDescription = "error_description"
    }
}

private struct UserResponse: Decodable {
    let login: String
    let name: String?
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case login
        case name
        case avatarURL = "avatar_url"
    }
}

private struct APIErrorResponse: Decodable {
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case errorDescription = "error_description"
    }
}
