import AppKit
import Foundation

enum RepositoryLocalActionError: LocalizedError {
    case pathNotDirectory(String)
    case missingCloneURL
    case destinationAlreadyExists(String)
    case destinationNotDirectory(String)
    case gitNotAvailable
    case gitBlockedBySandbox
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .pathNotDirectory(let path):
            return "Local path is not a directory: \(path)"
        case .missingCloneURL:
            return "Repository does not expose a clone URL."
        case .destinationAlreadyExists(let path):
            return "Destination folder is not empty: \(path)"
        case .destinationNotDirectory(let path):
            return "Destination path exists but is not a folder: \(path)"
        case .gitNotAvailable:
            return "Git is not available in common system locations."
        case .gitBlockedBySandbox:
            return "Git clone is blocked by App Sandbox for the available Git binary. Install Git via Homebrew (for example /opt/homebrew/bin/git) and try again."
        case .commandFailed(let message):
            return message
        }
    }
}

protocol RepositoryLocalActionServicing {
    func openInFinder(at localURL: URL) throws
    func openInTerminal(at localURL: URL) throws
    func cloneRepository(
        sshCloneURL: String?,
        httpsCloneURL: String?,
        accessToken: String?,
        into rootURL: URL,
        directoryName: String
    ) async throws -> URL
}

struct RepositoryLocalActionService: RepositoryLocalActionServicing {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func openInFinder(at localURL: URL) throws {
        try ensureDirectory(at: localURL)

        try withSecurityScopedAccess(to: localURL) {
            NSWorkspace.shared.activateFileViewerSelecting([localURL])
        }
    }

    func openInTerminal(at localURL: URL) throws {
        try ensureDirectory(at: localURL)

        try withSecurityScopedAccess(to: localURL) {
            let terminalStatus = try runProcessSync(
                executablePath: "/usr/bin/open",
                arguments: ["-a", "Terminal", localURL.path],
                currentDirectoryURL: nil
            )

            if terminalStatus != 0 {
                throw RepositoryLocalActionError.commandFailed("Unable to open Terminal at local repository path.")
            }
        }
    }

    func cloneRepository(
        sshCloneURL: String?,
        httpsCloneURL: String?,
        accessToken: String?,
        into rootURL: URL,
        directoryName: String
    ) async throws -> URL {
        let trimmedSSHCloneURL = sshCloneURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedHTTPSCloneURL = httpsCloneURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedSSHCloneURL.isEmpty || !trimmedHTTPSCloneURL.isEmpty else {
            throw RepositoryLocalActionError.missingCloneURL
        }

        let gitExecutablePaths = availableGitExecutablePaths()
        guard !gitExecutablePaths.isEmpty else {
            throw RepositoryLocalActionError.gitNotAvailable
        }

        let destinationURL = rootURL.appendingPathComponent(directoryName, isDirectory: true)
        let destinationExistedBeforeClone = fileManager.fileExists(atPath: destinationURL.path)

        let hasSecurityAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw RepositoryLocalActionError.destinationNotDirectory(destinationURL.path)
            }

            if !isDirectoryEmpty(destinationURL) {
                throw RepositoryLocalActionError.destinationAlreadyExists(destinationURL.path)
            }
        }

        let cloneConfigurations = buildCloneConfigurations(
            sshCloneURL: trimmedSSHCloneURL,
            httpsCloneURL: trimmedHTTPSCloneURL,
            accessToken: accessToken
        )

        var hasSandboxBlockedGit = false

        do {
            for executablePath in gitExecutablePaths {
                for configuration in cloneConfigurations {
                    let result = try await runProcess(
                        executablePath: executablePath,
                        arguments: configuration.arguments(destinationPath: destinationURL.path),
                        currentDirectoryURL: rootURL
                    )

                    if result.exitCode == 0 {
                        return destinationURL
                    }

                    let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

                    if isSandboxBlockedXcrunError(stderr: stderr, stdout: stdout) {
                        hasSandboxBlockedGit = true
                        continue
                    }

                    if !stderr.isEmpty {
                        throw RepositoryLocalActionError.commandFailed(stderr)
                    } else if !stdout.isEmpty {
                        throw RepositoryLocalActionError.commandFailed(stdout)
                    } else {
                        throw RepositoryLocalActionError.commandFailed("Unable to clone repository.")
                    }
                }
            }

            if hasSandboxBlockedGit {
                throw RepositoryLocalActionError.gitBlockedBySandbox
            } else {
                throw RepositoryLocalActionError.commandFailed("Unable to clone repository.")
            }
        } catch {
            cleanupDestinationIfNeeded(
                destinationURL: destinationURL,
                destinationExistedBeforeClone: destinationExistedBeforeClone
            )
            throw error
        }
    }

    private struct CloneConfiguration {
        let cloneURL: String
        let extraGitConfigs: [String]

        func arguments(destinationPath: String) -> [String] {
            var args: [String] = []
            for config in extraGitConfigs {
                args.append("-c")
                args.append(config)
            }
            args.append(contentsOf: ["clone", "--", cloneURL, destinationPath])
            return args
        }
    }

    private func isDirectoryEmpty(_ directoryURL: URL) -> Bool {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
            return contents.isEmpty
        } catch {
            return false
        }
    }

    private func buildCloneConfigurations(
        sshCloneURL: String,
        httpsCloneURL: String,
        accessToken: String?
    ) -> [CloneConfiguration] {
        var configurations: [CloneConfiguration] = []

        if !httpsCloneURL.isEmpty {
            let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let authHeader = basicAuthHeader(forAccessToken: token) {
                configurations.append(
                    CloneConfiguration(
                        cloneURL: httpsCloneURL,
                        extraGitConfigs: ["http.extraHeader=Authorization: Basic \(authHeader)"]
                    )
                )
            }

            configurations.append(
                CloneConfiguration(cloneURL: httpsCloneURL, extraGitConfigs: [])
            )
        }

        if !sshCloneURL.isEmpty {
            configurations.append(
                CloneConfiguration(cloneURL: sshCloneURL, extraGitConfigs: [])
            )
        }

        return configurations
    }

    private func basicAuthHeader(forAccessToken accessToken: String) -> String? {
        guard !accessToken.isEmpty else {
            return nil
        }

        let credentials = "x-access-token:\(accessToken)"
        return Data(credentials.utf8).base64EncodedString()
    }

    private func availableGitExecutablePaths() -> [String] {
        var candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git"
        ]

        // `/usr/bin/git` generally resolves through `xcrun`, which is commonly blocked in App Sandbox.
        // Keep it as a last-resort fallback only when no other git binary is available.
        if !candidates.contains(where: { fileManager.isExecutableFile(atPath: $0) }) {
            candidates.append("/usr/bin/git")
        }

        var seen: Set<String> = []
        var paths: [String] = []

        for candidate in candidates where seen.insert(candidate).inserted {
            if fileManager.isExecutableFile(atPath: candidate) {
                paths.append(candidate)
            }
        }

        return paths
    }

    private func isSandboxBlockedXcrunError(stderr: String, stdout: String) -> Bool {
        let mergedOutput = "\(stderr)\n\(stdout)".lowercased()
        return mergedOutput.contains("xcrun: error: cannot be used within an app sandbox")
    }

    private func cleanupDestinationIfNeeded(
        destinationURL: URL,
        destinationExistedBeforeClone: Bool
    ) {
        guard !destinationExistedBeforeClone else {
            return
        }

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            return
        }

        _ = try? fileManager.removeItem(at: destinationURL)
    }

    private func ensureDirectory(at localURL: URL) throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: localURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            throw RepositoryLocalActionError.pathNotDirectory(localURL.path)
        }
    }

    private func withSecurityScopedAccess<T>(to url: URL, operation: () throws -> T) throws -> T {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    private func runProcessSync(
        executablePath: String,
        arguments: [String],
        currentDirectoryURL: URL?
    ) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            throw RepositoryLocalActionError.commandFailed("Failed to execute local command.")
        }
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        currentDirectoryURL: URL?
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: RepositoryLocalActionError.commandFailed("Failed to execute git clone command."))
            }
        }
    }
}
