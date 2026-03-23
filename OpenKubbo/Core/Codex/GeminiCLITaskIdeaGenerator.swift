import Foundation

enum GeminiTaskIdeaError: LocalizedError {
    case executableNotFound
    case nodeRuntimeNotFound
    case invalidResponse
    case sandboxedBuildUnsupported
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Gemini CLI was not found. Install `gemini` first."
        case .nodeRuntimeNotFound:
            return "Node.js runtime was not found. In Settings > API Keys, choose `/usr/local/bin/node`."
        case .invalidResponse:
            return "Gemini CLI returned an invalid task list. Please try again."
        case .sandboxedBuildUnsupported:
            return "This sandboxed build cannot launch Gemini CLI. Run the Debug build from Xcode to use your local Gemini session."
        case .commandFailed(let message):
            return message
        }
    }
}

final class GeminiCLITaskIdeaGenerator: TaskIdeaGenerating {
    private struct TaskIdeaPayload: Decodable {
        let tasks: [String]
    }

    private struct HeadlessResponse: Decodable {
        struct ResponseError: Decodable {
            let message: String?
        }

        let response: String?
        let error: ResponseError?
    }

    private struct ExecutableDescriptor {
        let path: String
        let bookmarkData: Data?
    }

    private struct LaunchConfiguration {
        let executablePath: String
        let arguments: [String]
    }

    private let settingsRepository: SettingsRepository
    private let apiKeyStore: GeminiAPIKeyStoring
    private let executableResolver: GeminiCLIExecutableResolving
    private let nodeExecutableResolver: NodeRuntimeExecutableResolving
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(
        settingsRepository: SettingsRepository,
        apiKeyStore: GeminiAPIKeyStoring,
        executableResolver: GeminiCLIExecutableResolving,
        nodeExecutableResolver: NodeRuntimeExecutableResolving,
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.settingsRepository = settingsRepository
        self.apiKeyStore = apiKeyStore
        self.executableResolver = executableResolver
        self.nodeExecutableResolver = nodeExecutableResolver
        self.fileManager = fileManager
        self.decoder = decoder
    }

    func generateTasks(from idea: String) async throws -> [String] {
        let trimmedIdea = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdea.isEmpty else {
            throw GeminiTaskIdeaError.invalidResponse
        }

        guard canUseLocalGeminiCLI else {
            throw GeminiTaskIdeaError.sandboxedBuildUnsupported
        }

        let executableDescriptor = try resolvedExecutableDescriptor()
        let nodeExecutableDescriptor = try resolvedNodeExecutableDescriptor(for: executableDescriptor)
        let workingDirectoryURL = try prepareGeminiHomeDirectory()

        let launchConfiguration = try launchConfiguration(
            for: executableDescriptor,
            nodeExecutableDescriptor: nodeExecutableDescriptor,
            arguments: executionArguments(
                prompt: prompt(for: trimmedIdea),
                model: normalizedModelIdentifier
            )
        )

        let generationResult = try await withSecurityScopedExecutableAccess(
            descriptors: [executableDescriptor, nodeExecutableDescriptor].compactMap { $0 }
        ) {
            try await runProcess(
                executablePath: launchConfiguration.executablePath,
                arguments: launchConfiguration.arguments,
                currentDirectoryURL: workingDirectoryURL,
                environment: executionEnvironment()
            )
        }

        guard generationResult.exitCode == 0 else {
            throw GeminiTaskIdeaError.commandFailed(
                normalizedLocalCLIError(stderr: generationResult.stderr, stdout: generationResult.stdout)
            )
        }

        guard let responseData = generationResult.stdout.data(using: .utf8) else {
            throw GeminiTaskIdeaError.invalidResponse
        }

        let payload: HeadlessResponse
        do {
            payload = try decoder.decode(HeadlessResponse.self, from: responseData)
        } catch {
            throw GeminiTaskIdeaError.invalidResponse
        }

        if let errorMessage = payload.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !errorMessage.isEmpty {
            throw GeminiTaskIdeaError.commandFailed(errorMessage)
        }

        let outputText = normalizedJSONResponse(from: payload.response)
        guard let outputData = outputText.data(using: .utf8) else {
            throw GeminiTaskIdeaError.invalidResponse
        }

        let taskPayload: TaskIdeaPayload
        do {
            taskPayload = try decoder.decode(TaskIdeaPayload.self, from: outputData)
        } catch {
            throw GeminiTaskIdeaError.invalidResponse
        }

        let titles = deduplicatedTaskTitles(from: taskPayload.tasks)
        guard !titles.isEmpty else {
            throw GeminiTaskIdeaError.invalidResponse
        }

        return titles
    }

    private var canUseLocalGeminiCLI: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
    }

    private var normalizedModelIdentifier: String? {
        let rawValue = settingsRepository.load().geminiSelectedModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rawValue.isEmpty ? nil : rawValue
    }

    private var normalizedAPIKey: String? {
        let rawValue = apiKeyStore.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return rawValue.isEmpty ? nil : rawValue
    }

    private func resolvedExecutableDescriptor() throws -> ExecutableDescriptor {
        let snapshot = settingsRepository.load()

        if let manualPath = snapshot.geminiExecutablePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !manualPath.isEmpty {
            return ExecutableDescriptor(
                path: manualPath,
                bookmarkData: snapshot.geminiExecutableBookmarkData
            )
        }

        guard let detectedPath = executableResolver.resolveExecutablePath() else {
            throw GeminiTaskIdeaError.executableNotFound
        }

        return ExecutableDescriptor(path: detectedPath, bookmarkData: nil)
    }

    private func resolvedNodeExecutableDescriptor(
        for executableDescriptor: ExecutableDescriptor
    ) throws -> ExecutableDescriptor? {
        guard requiresNodeRuntime(for: executableDescriptor) else {
            return nil
        }

        let snapshot = settingsRepository.load()
        if let manualPath = snapshot.nodeExecutablePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !manualPath.isEmpty {
            return ExecutableDescriptor(
                path: manualPath,
                bookmarkData: snapshot.nodeExecutableBookmarkData
            )
        }

        guard let detectedPath = nodeExecutableResolver.resolveNodeExecutablePath() else {
            throw GeminiTaskIdeaError.nodeRuntimeNotFound
        }

        return ExecutableDescriptor(path: detectedPath, bookmarkData: nil)
    }

    private func launchConfiguration(
        for executableDescriptor: ExecutableDescriptor,
        nodeExecutableDescriptor: ExecutableDescriptor?,
        arguments: [String]
    ) throws -> LaunchConfiguration {
        let launchPath = preferredLaunchPath(for: executableDescriptor)

        if let nodeExecutableDescriptor {
            return LaunchConfiguration(
                executablePath: preferredLaunchPath(for: nodeExecutableDescriptor),
                arguments: [launchPath] + arguments
            )
        }

        return LaunchConfiguration(executablePath: launchPath, arguments: arguments)
    }

    private func prepareGeminiHomeDirectory() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let geminiHomeURL = applicationSupportURL
            .appendingPathComponent("OpenKubbo", isDirectory: true)
            .appendingPathComponent("GeminiCLI", isDirectory: true)

        try fileManager.createDirectory(at: geminiHomeURL, withIntermediateDirectories: true, attributes: nil)
        return geminiHomeURL
    }

    private func executionArguments(prompt: String, model: String?) -> [String] {
        var arguments = [
            "-p",
            prompt,
            "--output-format",
            "json"
        ]

        if let model {
            arguments.append(contentsOf: ["--model", model])
        }

        return arguments
    }

    private func executionEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = effectiveExecutionPATH

        if let normalizedAPIKey {
            environment["GEMINI_API_KEY"] = normalizedAPIKey
        }

        return environment
    }

    private var effectiveExecutionPATH: String {
        let fallbackPath = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        if let inheritedPath = ProcessInfo.processInfo.environment["PATH"],
           !inheritedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(fallbackPath):\(inheritedPath)"
        }

        return fallbackPath
    }

    private func prompt(for idea: String) -> String {
        """
        Break the user's idea into 4 to 8 small, actionable task titles for a lightweight task manager.
        Return only valid JSON that matches this shape and nothing else:
        {"tasks":["Task 1","Task 2"]}

        Rules:
        - Keep the same language as the user's idea.
        - Each task must be independent and specific.
        - Use plain text only.
        - Do not number the tasks.
        - Do not include headings, notes, explanations, or Markdown code fences.
        - Favor short titles that fit naturally in a compact task card.

        Idea:
        \(idea)
        """
    }

    private func normalizedJSONResponse(from response: String?) -> String {
        let trimmedResponse = response?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmedResponse.isEmpty else {
            return ""
        }

        if trimmedResponse.hasPrefix("```"),
           let stripped = strippedCodeFence(from: trimmedResponse) {
            return stripped
        }

        return trimmedResponse
    }

    private func strippedCodeFence(from response: String) -> String? {
        let lines = response
            .components(separatedBy: .newlines)
            .dropFirst()
            .dropLast()

        let stripped = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }

    private func deduplicatedTaskTitles(from rawTitles: [String]) -> [String] {
        var seen = Set<String>()
        var titles: [String] = []

        for rawTitle in rawTitles {
            let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else {
                continue
            }

            let normalizedKey = trimmedTitle.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )

            guard seen.insert(normalizedKey).inserted else {
                continue
            }

            titles.append(trimmedTitle)
        }

        return titles
    }

    private func preferredLaunchPath(for executableDescriptor: ExecutableDescriptor) -> String {
        guard executableDescriptor.bookmarkData == nil else {
            return executableDescriptor.path
        }

        let resolvedPath = URL(fileURLWithPath: executableDescriptor.path).resolvingSymlinksInPath().path
        return resolvedPath.isEmpty ? executableDescriptor.path : resolvedPath
    }

    private func requiresNodeRuntime(for executableDescriptor: ExecutableDescriptor) -> Bool {
        let launchPath = preferredLaunchPath(for: executableDescriptor)
        if launchPath.lowercased().hasSuffix(".js") {
            return true
        }

        guard fileManager.fileExists(atPath: launchPath),
              let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: launchPath)) else {
            return false
        }
        defer {
            try? handle.close()
        }

        guard let data = try? handle.read(upToCount: 160),
              let shebang = String(data: data, encoding: .utf8)?
                .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) else {
            return false
        }

        return shebang.hasPrefix("#!") && shebang.contains("node")
    }

    private func normalizedCommandOutput(stderr: String, stdout: String) -> String {
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedError.isEmpty {
            return trimmedError
        }

        let trimmedOutput = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOutput.isEmpty {
            return trimmedOutput
        }

        return "Gemini CLI failed to generate tasks."
    }

    private func normalizedLocalCLIError(stderr: String, stdout: String) -> String {
        let message = normalizedCommandOutput(stderr: stderr, stdout: stdout)
        let normalizedMessage = message.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if normalizedMessage.contains("login") ||
            normalizedMessage.contains("log in") ||
            normalizedMessage.contains("sign in") ||
            normalizedMessage.contains("not authenticated") ||
            normalizedMessage.contains("authentication") ||
            normalizedMessage.contains("credentials") ||
            normalizedMessage.contains("api key") {
            return "Gemini CLI is installed, but your local session is not authenticated. In Terminal, run `gemini` and choose Sign in with Google, or save a Gemini API key in Settings > API Keys."
        }

        return message
    }

    private func withSecurityScopedExecutableAccess<T>(
        descriptors: [ExecutableDescriptor],
        operation: () async throws -> T
    ) async throws -> T {
        let bookmarkPayloads = descriptors.compactMap(\.bookmarkData)
        guard !bookmarkPayloads.isEmpty else {
            return try await operation()
        }

        var securityScopedURLs: [URL] = []
        for bookmarkData in bookmarkPayloads {
            var isStale = false
            let executableURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if executableURL.startAccessingSecurityScopedResource() {
                securityScopedURLs.append(executableURL)
            }
        }
        defer {
            for executableURL in securityScopedURLs {
                executableURL.stopAccessingSecurityScopedResource()
            }
        }

        return try await operation()
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        currentDirectoryURL: URL?,
        environment: [String: String],
        standardInputData: Data? = nil
    ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectoryURL
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdinPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = stdinPipe

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()

                if let standardInputData {
                    stdinPipe.fileHandleForWriting.write(standardInputData)
                }
                stdinPipe.fileHandleForWriting.closeFile()
            } catch {
                try? stdinPipe.fileHandleForWriting.close()
                continuation.resume(
                    throwing: GeminiTaskIdeaError.commandFailed(
                        error.localizedDescription.isEmpty
                            ? "Failed to execute Gemini CLI."
                            : error.localizedDescription
                    )
                )
            }
        }
    }
}
