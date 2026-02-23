import AppKit
import Foundation

enum RepositoryLocalActionError: LocalizedError {
    case pathNotDirectory(String)
    case missingSSHCloneURL
    case destinationAlreadyExists(String)
    case destinationNotDirectory(String)
    case gitNotAvailable
    case gitBlockedBySandbox
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .pathNotDirectory(let path):
            return "Local path is not a directory: \(path)"
        case .missingSSHCloneURL:
            return "Repository does not expose an SSH clone URL."
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
    func cloneRepository(sshCloneURL: String, into rootURL: URL, directoryName: String) async throws -> URL
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

    func cloneRepository(sshCloneURL: String, into rootURL: URL, directoryName: String) async throws -> URL {
        let trimmedCloneURL = sshCloneURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCloneURL.isEmpty else {
            throw RepositoryLocalActionError.missingSSHCloneURL
        }

        let gitExecutablePaths = availableGitExecutablePaths()
        guard !gitExecutablePaths.isEmpty else {
            throw RepositoryLocalActionError.gitNotAvailable
        }

        let destinationURL = rootURL.appendingPathComponent(directoryName, isDirectory: true)

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

        var hasSandboxBlockedGit = false
        var lastCloneErrorMessage: String?

        for executablePath in gitExecutablePaths {
            let result = try await runProcess(
                executablePath: executablePath,
                arguments: ["clone", "--", trimmedCloneURL, destinationURL.path],
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
                lastCloneErrorMessage = stderr
            } else if !stdout.isEmpty {
                lastCloneErrorMessage = stdout
            }
        }

        if hasSandboxBlockedGit {
            throw RepositoryLocalActionError.gitBlockedBySandbox
        }

        if let lastCloneErrorMessage {
            throw RepositoryLocalActionError.commandFailed(lastCloneErrorMessage)
        }

        throw RepositoryLocalActionError.commandFailed("Unable to clone repository.")
    }

    private func isDirectoryEmpty(_ directoryURL: URL) -> Bool {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
            return contents.isEmpty
        } catch {
            return false
        }
    }

    private func availableGitExecutablePaths() -> [String] {
        let candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/Library/Developer/CommandLineTools/usr/bin/git",
            "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
            "/usr/bin/git"
        ]

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
