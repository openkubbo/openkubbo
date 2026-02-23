import AppKit
import Foundation

enum RepositoryLocalActionError: LocalizedError {
    case pathNotDirectory(String)
    case missingSSHCloneURL
    case destinationAlreadyExists(String)
    case destinationNotDirectory(String)
    case gitNotAvailable
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
            return "Git is not available at /usr/bin/git."
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

        guard fileManager.isExecutableFile(atPath: "/usr/bin/git") else {
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

        let result = try await runProcess(
            executablePath: "/usr/bin/git",
            arguments: ["clone", "--", trimmedCloneURL, destinationURL.path],
            currentDirectoryURL: rootURL
        )

        if result.exitCode != 0 {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                throw RepositoryLocalActionError.commandFailed(message)
            }

            throw RepositoryLocalActionError.commandFailed("Unable to clone repository.")
        }

        return destinationURL
    }

    private func isDirectoryEmpty(_ directoryURL: URL) -> Bool {
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directoryURL.path)
            return contents.isEmpty
        } catch {
            return false
        }
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
