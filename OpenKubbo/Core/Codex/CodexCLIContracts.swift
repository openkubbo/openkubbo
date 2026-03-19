import Foundation

protocol CodexAPIKeyStoring {
    func apiKey() -> String?
    func save(apiKey: String)
    func clear()
}

protocol GeminiAPIKeyStoring {
    func apiKey() -> String?
    func save(apiKey: String)
    func clear()
}

protocol CodexCLIExecutableResolving {
    func resolveExecutablePath() -> String?
}

protocol GeminiCLIExecutableResolving {
    func resolveExecutablePath() -> String?
}

protocol NodeRuntimeExecutableResolving {
    func resolveNodeExecutablePath() -> String?
}

protocol TaskIdeaGenerating {
    func generateTasks(from idea: String) async throws -> [String]
}

struct DefaultCodexCLIExecutableResolver: CodexCLIExecutableResolving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolveExecutablePath() -> String? {
        resolveLaunchablePath(
            candidatePaths: candidateExecutablePaths,
            shellCommand: "codex",
            fileManager: fileManager
        )
    }

    private var candidateExecutablePaths: [String] {
        let homePath = fileManager.homeDirectoryForCurrentUser.path

        return [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/lib/node_modules/@openai/codex/bin/codex.js",
            "/opt/homebrew/lib/node_modules/@openai/codex/bin/codex.js",
            "\(homePath)/.npm-global/bin/codex",
            "\(homePath)/.local/bin/codex",
            "\(homePath)/.nvm/versions/node/current/bin/codex"
        ]
    }
}

struct DefaultNodeRuntimeExecutableResolver: NodeRuntimeExecutableResolving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolveNodeExecutablePath() -> String? {
        let homePath = fileManager.homeDirectoryForCurrentUser.path

        return resolveLaunchablePath(
            candidatePaths: [
                "/usr/local/bin/node",
                "/opt/homebrew/bin/node",
                "\(homePath)/.npm-global/bin/node",
                "\(homePath)/.local/bin/node",
                "\(homePath)/.nvm/versions/node/current/bin/node"
            ],
            shellCommand: "node",
            fileManager: fileManager
        )
    }
}

struct DefaultGeminiCLIExecutableResolver: GeminiCLIExecutableResolving {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolveExecutablePath() -> String? {
        resolveLaunchablePath(
            candidatePaths: candidateExecutablePaths,
            shellCommand: "gemini",
            fileManager: fileManager
        )
    }

    private var candidateExecutablePaths: [String] {
        let homePath = fileManager.homeDirectoryForCurrentUser.path

        return [
            "/usr/local/bin/gemini",
            "/opt/homebrew/bin/gemini",
            "/usr/local/lib/node_modules/@google/gemini-cli/bin/gemini.js",
            "/opt/homebrew/lib/node_modules/@google/gemini-cli/bin/gemini.js",
            "\(homePath)/.npm-global/bin/gemini",
            "\(homePath)/.local/bin/gemini",
            "\(homePath)/.nvm/versions/node/current/bin/gemini"
        ]
    }
}

enum CodexTaskIdeaError: LocalizedError {
    case missingAPIKey
    case executableNotFound
    case nodeRuntimeNotFound
    case invalidResponse
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Install and sign in to Codex CLI, or save an OpenAI API key in Settings > API Keys."
        case .executableNotFound:
            return "Codex CLI was not found. Install `codex` first."
        case .nodeRuntimeNotFound:
            return "Node.js runtime was not found. In Settings > API Keys, choose `/usr/local/bin/node`."
        case .invalidResponse:
            return "Codex CLI returned an invalid task list. Please try again."
        case .commandFailed(let message):
            return message
        }
    }
}

private func resolveLaunchablePath(
    candidatePaths: [String],
    shellCommand: String,
    fileManager: FileManager
) -> String? {
    for candidatePath in candidatePaths {
        if isLaunchableExecutable(atPath: candidatePath, fileManager: fileManager) {
            return candidatePath
        }

        let resolvedPath = URL(fileURLWithPath: candidatePath).resolvingSymlinksInPath().path
        if resolvedPath != candidatePath,
           isLaunchableExecutable(atPath: resolvedPath, fileManager: fileManager) {
            return resolvedPath
        }
    }

    if let shellResolvedPath = shellResolvedExecutablePath(shellCommand: shellCommand), !shellResolvedPath.isEmpty {
        return shellResolvedPath
    }

    return nil
}

private func isLaunchableExecutable(atPath path: String, fileManager: FileManager) -> Bool {
    fileManager.fileExists(atPath: path) && fileManager.isExecutableFile(atPath: path)
}

private func shellResolvedExecutablePath(shellCommand: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", "command -v \(shellCommand)"]

    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let output, !output.isEmpty else {
            return nil
        }

        let resolvedPath = URL(fileURLWithPath: output).resolvingSymlinksInPath().path
        return resolvedPath.isEmpty ? output : resolvedPath
    } catch {
        return nil
    }
}
