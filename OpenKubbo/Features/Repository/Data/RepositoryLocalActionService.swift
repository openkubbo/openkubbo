import AppKit
import Foundation

enum RepositoryLocalActionError: LocalizedError {
    case pathNotDirectory(String)
    case missingCloneURL
    case destinationAlreadyExists(String)
    case destinationNotDirectory(String)
    case gitNotAvailable
    case gitBlockedBySandbox
    case checkoutBlockedByLocalChanges
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
            return "Git command is blocked by App Sandbox for the available Git binary. Install Git via Homebrew (for example /opt/homebrew/bin/git) and try again."
        case .checkoutBlockedByLocalChanges:
            return "Cannot switch branch because this repository has local uncommitted changes. Commit, stash, or discard your changes, then try again."
        case .commandFailed(let message):
            return message
        }
    }
}

protocol RepositoryLocalActionServicing {
    func openInFinder(at localURL: URL) throws
    func openInTerminal(at localURL: URL) throws
    func checkoutBranch(named branchName: String, at localURL: URL) throws
    func currentBranchName(at localURL: URL) throws -> String?
    func listWorktrees(at localURL: URL) throws -> [RepoWorktreeItem]
    func createWorktree(
        branchName: String,
        at localURL: URL,
        directoryName: String
    ) throws -> URL
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
    private enum CheckoutBranchResult {
        case success
        case sandboxBlocked
        case failed(String)
    }
    private enum WorktreeAddResult {
        case success(URL)
        case sandboxBlocked
        case failed(String)
    }

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

    func checkoutBranch(named branchName: String, at localURL: URL) throws {
        try ensureDirectory(at: localURL)

        let trimmedBranchName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranchName.isEmpty else {
            throw RepositoryLocalActionError.commandFailed("Branch name is empty.")
        }

        let gitExecutablePaths = availableGitExecutablePaths()
        guard !gitExecutablePaths.isEmpty else {
            throw RepositoryLocalActionError.gitNotAvailable
        }

        try withSecurityScopedAccess(to: localURL) {
            var hasSandboxBlockedGit = false

            for executablePath in gitExecutablePaths {
                let localBranchRef = "refs/heads/\(trimmedBranchName)"
                let localBranchProbe = try runProcessSyncWithOutput(
                    executablePath: executablePath,
                    arguments: ["show-ref", "--verify", "--quiet", localBranchRef],
                    currentDirectoryURL: localURL
                )

                if isSandboxBlockedXcrunError(stderr: localBranchProbe.stderr, stdout: localBranchProbe.stdout) {
                    hasSandboxBlockedGit = true
                    continue
                }

                let probeFailure = normalizedCommandOutput(
                    stderr: localBranchProbe.stderr,
                    stdout: localBranchProbe.stdout
                )
                if localBranchProbe.exitCode != 0 && localBranchProbe.exitCode != 1 && !probeFailure.isEmpty {
                    throw RepositoryLocalActionError.commandFailed(probeFailure)
                }

                if localBranchProbe.exitCode == 0 {
                    let localCheckout = try attemptCheckoutBranch(
                        named: trimmedBranchName,
                        using: executablePath,
                        in: localURL,
                        attempts: [
                            ["switch", trimmedBranchName],
                            ["checkout", trimmedBranchName]
                        ],
                        allowExistingBranchRecovery: false
                    )

                    switch localCheckout {
                    case .success:
                        return
                    case .sandboxBlocked:
                        hasSandboxBlockedGit = true
                        continue
                    case .failed(let message):
                        if isCheckoutBlockedByLocalChanges(message) {
                            throw RepositoryLocalActionError.checkoutBlockedByLocalChanges
                        }
                        throw RepositoryLocalActionError.commandFailed(message)
                    }
                }

                let fetchResult = try runProcessSyncWithOutput(
                    executablePath: executablePath,
                    arguments: ["fetch", "--quiet", "origin", trimmedBranchName],
                    currentDirectoryURL: localURL
                )

                if isSandboxBlockedXcrunError(stderr: fetchResult.stderr, stdout: fetchResult.stdout) {
                    hasSandboxBlockedGit = true
                    continue
                }

                if fetchResult.exitCode != 0 {
                    let failure = normalizedCommandOutput(stderr: fetchResult.stderr, stdout: fetchResult.stdout)
                    throw RepositoryLocalActionError.commandFailed(
                        failure.isEmpty ? "Unable to fetch branch '\(trimmedBranchName)' from origin." : failure
                    )
                }

                let remoteCheckout = try attemptCheckoutBranch(
                    named: trimmedBranchName,
                    using: executablePath,
                    in: localURL,
                    attempts: [
                        ["switch", "--track", "origin/\(trimmedBranchName)"],
                        ["checkout", "--track", "-b", trimmedBranchName, "origin/\(trimmedBranchName)"],
                        ["checkout", "-t", "origin/\(trimmedBranchName)"],
                        ["switch", trimmedBranchName],
                        ["checkout", trimmedBranchName]
                    ],
                    allowExistingBranchRecovery: true
                )

                switch remoteCheckout {
                case .success:
                    return
                case .sandboxBlocked:
                    hasSandboxBlockedGit = true
                    continue
                case .failed(let message):
                    if isCheckoutBlockedByLocalChanges(message) {
                        throw RepositoryLocalActionError.checkoutBlockedByLocalChanges
                    }
                    throw RepositoryLocalActionError.commandFailed(message)
                }
            }

            if hasSandboxBlockedGit {
                throw RepositoryLocalActionError.gitBlockedBySandbox
            }

            throw RepositoryLocalActionError.commandFailed("Unable to checkout branch '\(trimmedBranchName)'.")
        }
    }

    func currentBranchName(at localURL: URL) throws -> String? {
        try ensureDirectory(at: localURL)

        let gitExecutablePaths = availableGitExecutablePaths()
        guard !gitExecutablePaths.isEmpty else {
            throw RepositoryLocalActionError.gitNotAvailable
        }

        return try withSecurityScopedAccess(to: localURL) {
            var hasSandboxBlockedGit = false

            for executablePath in gitExecutablePaths {
                let symbolicRefResult = try runProcessSyncWithOutput(
                    executablePath: executablePath,
                    arguments: ["symbolic-ref", "--short", "HEAD"],
                    currentDirectoryURL: localURL
                )

                if isSandboxBlockedXcrunError(stderr: symbolicRefResult.stderr, stdout: symbolicRefResult.stdout) {
                    hasSandboxBlockedGit = true
                    continue
                }

                let symbolicBranch = normalizedCommandOutput(
                    stderr: symbolicRefResult.stderr,
                    stdout: symbolicRefResult.stdout
                )
                if symbolicRefResult.exitCode == 0, !symbolicBranch.isEmpty {
                    return symbolicBranch
                }

                let revParseResult = try runProcessSyncWithOutput(
                    executablePath: executablePath,
                    arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
                    currentDirectoryURL: localURL
                )

                if isSandboxBlockedXcrunError(stderr: revParseResult.stderr, stdout: revParseResult.stdout) {
                    hasSandboxBlockedGit = true
                    continue
                }

                if revParseResult.exitCode != 0 {
                    continue
                }

                let parsedBranch = normalizedCommandOutput(stderr: revParseResult.stderr, stdout: revParseResult.stdout)
                if parsedBranch.isEmpty || parsedBranch == "HEAD" {
                    continue
                }

                return parsedBranch
            }

            if hasSandboxBlockedGit {
                throw RepositoryLocalActionError.gitBlockedBySandbox
            }

            return nil
        }
    }

    func listWorktrees(at localURL: URL) throws -> [RepoWorktreeItem] {
        try ensureDirectory(at: localURL)

        let gitExecutablePaths = availableGitExecutablePaths()
        guard !gitExecutablePaths.isEmpty else {
            throw RepositoryLocalActionError.gitNotAvailable
        }

        return try withSecurityScopedAccess(to: localURL) {
            var hasSandboxBlockedGit = false
            var lastFailureMessage: String?

            for executablePath in gitExecutablePaths {
                let result = try runProcessSyncWithOutput(
                    executablePath: executablePath,
                    arguments: ["worktree", "list", "--porcelain"],
                    currentDirectoryURL: localURL
                )

                if isSandboxBlockedXcrunError(stderr: result.stderr, stdout: result.stdout) {
                    hasSandboxBlockedGit = true
                    continue
                }

                if result.exitCode == 0 {
                    return parseWorktreeListOutput(result.stdout, currentDirectoryURL: localURL)
                }

                let failure = normalizedCommandOutput(stderr: result.stderr, stdout: result.stdout)
                if !failure.isEmpty {
                    lastFailureMessage = failure
                }
            }

            if hasSandboxBlockedGit {
                throw RepositoryLocalActionError.gitBlockedBySandbox
            }

            if let lastFailureMessage, !lastFailureMessage.isEmpty {
                throw RepositoryLocalActionError.commandFailed(lastFailureMessage)
            }

            throw RepositoryLocalActionError.commandFailed("Unable to list worktrees.")
        }
    }

    func createWorktree(
        branchName: String,
        at localURL: URL,
        directoryName: String
    ) throws -> URL {
        try ensureDirectory(at: localURL)

        let trimmedBranchName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranchName.isEmpty else {
            throw RepositoryLocalActionError.commandFailed("Branch name is empty.")
        }

        let trimmedDirectoryName = directoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDirectoryName.isEmpty else {
            throw RepositoryLocalActionError.commandFailed("Worktree directory name is empty.")
        }

        let gitExecutablePaths = availableGitExecutablePaths()
        guard !gitExecutablePaths.isEmpty else {
            throw RepositoryLocalActionError.gitNotAvailable
        }

        let destinationURL = localURL
            .deletingLastPathComponent()
            .appendingPathComponent(trimmedDirectoryName, isDirectory: true)

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: destinationURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw RepositoryLocalActionError.destinationNotDirectory(destinationURL.path)
            }

            if !isDirectoryEmpty(destinationURL) {
                throw RepositoryLocalActionError.destinationAlreadyExists(destinationURL.path)
            }
        }

        return try withSecurityScopedAccess(to: localURL) {
            var hasSandboxBlockedGit = false
            var lastFailureMessage: String?

            for executablePath in gitExecutablePaths {
                let result = try attemptCreateWorktree(
                    named: trimmedBranchName,
                    at: destinationURL,
                    using: executablePath,
                    in: localURL
                )

                switch result {
                case .success(let createdURL):
                    return createdURL
                case .sandboxBlocked:
                    hasSandboxBlockedGit = true
                case .failed(let message):
                    lastFailureMessage = message
                }
            }

            if hasSandboxBlockedGit {
                throw RepositoryLocalActionError.gitBlockedBySandbox
            }

            if let lastFailureMessage, !lastFailureMessage.isEmpty {
                throw RepositoryLocalActionError.commandFailed(lastFailureMessage)
            }

            throw RepositoryLocalActionError.commandFailed("Unable to create worktree '\(trimmedBranchName)'.")
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

    private func runProcessSyncWithOutput(
        executablePath: String,
        arguments: [String],
        currentDirectoryURL: URL?
    ) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            return (process.terminationStatus, stdout, stderr)
        } catch {
            throw RepositoryLocalActionError.commandFailed("Failed to execute local command.")
        }
    }

    private func normalizedCommandOutput(stderr: String, stdout: String) -> String {
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedError.isEmpty {
            return trimmedError
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseWorktreeListOutput(
        _ output: String,
        currentDirectoryURL: URL
    ) -> [RepoWorktreeItem] {
        let rawLines = output.components(separatedBy: .newlines)
        var groups: [[String]] = []
        var currentGroup: [String] = []

        for line in rawLines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup.removeAll(keepingCapacity: true)
                }
                continue
            }
            currentGroup.append(line)
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        let currentPath = normalizedLocalPath(currentDirectoryURL)
        var items: [RepoWorktreeItem] = []
        items.reserveCapacity(groups.count)

        for group in groups {
            var path: String?
            var branchName: String?
            var headSHA: String?

            for line in group {
                if line.hasPrefix("worktree ") {
                    let value = String(line.dropFirst("worktree ".count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        path = normalizedLocalPath(value)
                    }
                } else if line.hasPrefix("branch ") {
                    let reference = String(line.dropFirst("branch ".count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    branchName = parseWorktreeBranchName(reference)
                } else if line.hasPrefix("HEAD ") {
                    let value = String(line.dropFirst("HEAD ".count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        headSHA = value
                    }
                } else if line == "detached" {
                    branchName = nil
                }
            }

            guard let normalizedPath = path else {
                continue
            }

            items.append(
                RepoWorktreeItem(
                    id: normalizedPath,
                    path: normalizedPath,
                    branchName: branchName,
                    headSHA: headSHA,
                    isCurrent: normalizedPath == currentPath
                )
            )
        }

        if items.isEmpty {
            items = [
                RepoWorktreeItem(
                    id: currentPath,
                    path: currentPath,
                    branchName: nil,
                    headSHA: nil,
                    isCurrent: true
                )
            ]
        }

        return items.sorted { lhs, rhs in
            if lhs.isCurrent != rhs.isCurrent {
                return lhs.isCurrent
            }
            return lhs.directoryName.localizedCaseInsensitiveCompare(rhs.directoryName) == .orderedAscending
        }
    }

    private func parseWorktreeBranchName(_ reference: String) -> String? {
        guard !reference.isEmpty else {
            return nil
        }

        let localPrefix = "refs/heads/"
        if reference.hasPrefix(localPrefix) {
            let branch = String(reference.dropFirst(localPrefix.count))
            return branch.isEmpty ? nil : branch
        }

        return reference
    }

    private func attemptCreateWorktree(
        named branchName: String,
        at destinationURL: URL,
        using executablePath: String,
        in localURL: URL
    ) throws -> WorktreeAddResult {
        let attempts: [[String]] = [
            ["worktree", "add", destinationURL.path, branchName],
            ["worktree", "add", "--track", "-b", branchName, destinationURL.path, "origin/\(branchName)"],
            ["worktree", "add", "-b", branchName, destinationURL.path]
        ]

        var lastFailureMessage: String?

        for arguments in attempts {
            let result = try runProcessSyncWithOutput(
                executablePath: executablePath,
                arguments: arguments,
                currentDirectoryURL: localURL
            )

            if result.exitCode == 0 {
                return .success(destinationURL)
            }

            if isSandboxBlockedXcrunError(stderr: result.stderr, stdout: result.stdout) {
                return .sandboxBlocked
            }

            let failure = normalizedCommandOutput(stderr: result.stderr, stdout: result.stdout)
            if failure.isEmpty {
                continue
            }

            if isWorktreeAlreadyCheckedOutError(failure) {
                return .failed("Branch '\(branchName)' is already checked out in another worktree.")
            }

            lastFailureMessage = failure
        }

        return .failed(lastFailureMessage ?? "Unable to create worktree '\(branchName)'.")
    }

    private func attemptCheckoutBranch(
        named branchName: String,
        using executablePath: String,
        in localURL: URL,
        attempts: [[String]],
        allowExistingBranchRecovery: Bool
    ) throws -> CheckoutBranchResult {
        var lastFailureMessage: String?

        for arguments in attempts {
            let result = try runProcessSyncWithOutput(
                executablePath: executablePath,
                arguments: arguments,
                currentDirectoryURL: localURL
            )

            if result.exitCode == 0 {
                return .success
            }

            if isSandboxBlockedXcrunError(stderr: result.stderr, stdout: result.stdout) {
                return .sandboxBlocked
            }

            let failure = normalizedCommandOutput(stderr: result.stderr, stdout: result.stdout)
            if failure.isEmpty {
                continue
            }

            if isCheckoutBlockedByLocalChanges(failure) {
                return .failed(failure)
            }

            if allowExistingBranchRecovery && isBranchAlreadyExistsError(failure, branchName: branchName) {
                let recovery = try runProcessSyncWithOutput(
                    executablePath: executablePath,
                    arguments: ["checkout", branchName],
                    currentDirectoryURL: localURL
                )

                if recovery.exitCode == 0 {
                    return .success
                }

                if isSandboxBlockedXcrunError(stderr: recovery.stderr, stdout: recovery.stdout) {
                    return .sandboxBlocked
                }

                let recoveryFailure = normalizedCommandOutput(stderr: recovery.stderr, stdout: recovery.stdout)
                if !recoveryFailure.isEmpty {
                    return .failed(recoveryFailure)
                }
            }

            lastFailureMessage = failure
        }

        return .failed(lastFailureMessage ?? "Unable to checkout branch '\(branchName)'.")
    }

    private func isBranchAlreadyExistsError(_ message: String, branchName: String) -> Bool {
        let lowercasedMessage = message.lowercased()
        let lowercasedBranchName = branchName.lowercased()
        return lowercasedMessage.contains("a branch named '\(lowercasedBranchName)' already exists")
            || lowercasedMessage.contains("branch '\(lowercasedBranchName)' already exists")
            || lowercasedMessage.contains("already exists")
    }

    private func isCheckoutBlockedByLocalChanges(_ message: String) -> Bool {
        let lowercasedMessage = message.lowercased()
        return lowercasedMessage.contains("would be overwritten by checkout")
            || lowercasedMessage.contains("please commit your changes or stash them before you switch branches")
    }

    private func isWorktreeAlreadyCheckedOutError(_ message: String) -> Bool {
        let lowercasedMessage = message.lowercased()
        return lowercasedMessage.contains("already checked out at")
            || lowercasedMessage.contains("is already used by worktree")
    }

    private func normalizedLocalPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func normalizedLocalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
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
