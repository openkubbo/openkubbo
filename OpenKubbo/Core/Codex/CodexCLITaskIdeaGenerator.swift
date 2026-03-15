import Foundation

final class CodexCLITaskIdeaGenerator: TaskIdeaGenerating {
    private struct TaskIdeaPayload: Decodable {
        let tasks: [String]
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
    private let apiKeyStore: CodexAPIKeyStoring
    private let executableResolver: CodexCLIExecutableResolving
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(
        settingsRepository: SettingsRepository,
        apiKeyStore: CodexAPIKeyStoring,
        executableResolver: CodexCLIExecutableResolving,
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.settingsRepository = settingsRepository
        self.apiKeyStore = apiKeyStore
        self.executableResolver = executableResolver
        self.fileManager = fileManager
        self.decoder = decoder
    }

    func generateTasks(from idea: String) async throws -> [String] {
        let trimmedIdea = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdea.isEmpty else {
            throw CodexTaskIdeaError.invalidResponse
        }

        guard let apiKey = normalizedAPIKey else {
            throw CodexTaskIdeaError.missingAPIKey
        }

        let executableDescriptor = try resolvedExecutableDescriptor()
        guard !executableDescriptor.path.isEmpty else {
            throw CodexTaskIdeaError.executableNotFound
        }

        let codexHomeURL = try prepareCodexHomeDirectory()
        let tempDirectoryURL = codexHomeURL.appendingPathComponent("temp", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let requestID = UUID().uuidString.lowercased()
        let schemaURL = tempDirectoryURL.appendingPathComponent("idea-schema-\(requestID).json")
        let outputURL = tempDirectoryURL.appendingPathComponent("idea-output-\(requestID).json")
        defer {
            try? fileManager.removeItem(at: schemaURL)
            try? fileManager.removeItem(at: outputURL)
        }

        try writeOutputSchema(to: schemaURL)

        let environment = executionEnvironment(codexHomeURL: codexHomeURL, apiKey: apiKey)

        let loginLaunchConfiguration = try launchConfiguration(
            for: executableDescriptor,
            arguments: ["login", "--with-api-key"]
        )

        let loginResult = try await withSecurityScopedExecutableAccess(bookmarkData: executableDescriptor.bookmarkData) {
            try await runProcess(
                executablePath: loginLaunchConfiguration.executablePath,
                arguments: loginLaunchConfiguration.arguments,
                currentDirectoryURL: codexHomeURL,
                environment: environment,
                standardInputData: Data(apiKey.utf8)
            )
        }

        guard loginResult.exitCode == 0 else {
            throw CodexTaskIdeaError.commandFailed(
                normalizedCommandOutput(stderr: loginResult.stderr, stdout: loginResult.stdout)
            )
        }

        let generationLaunchConfiguration = try launchConfiguration(
            for: executableDescriptor,
            arguments: executionArguments(
                schemaURL: schemaURL,
                outputURL: outputURL,
                prompt: prompt(for: trimmedIdea),
                model: normalizedModelIdentifier
            )
        )

        let generationResult = try await withSecurityScopedExecutableAccess(bookmarkData: executableDescriptor.bookmarkData) {
            try await runProcess(
                executablePath: generationLaunchConfiguration.executablePath,
                arguments: generationLaunchConfiguration.arguments,
                currentDirectoryURL: codexHomeURL,
                environment: environment
            )
        }

        guard generationResult.exitCode == 0 else {
            throw CodexTaskIdeaError.commandFailed(
                normalizedCommandOutput(stderr: generationResult.stderr, stdout: generationResult.stdout)
            )
        }

        guard fileManager.fileExists(atPath: outputURL.path) else {
            throw CodexTaskIdeaError.invalidResponse
        }

        let responseData = try Data(contentsOf: outputURL)
        let payload: TaskIdeaPayload
        do {
            payload = try decoder.decode(TaskIdeaPayload.self, from: responseData)
        } catch {
            throw CodexTaskIdeaError.invalidResponse
        }
        let titles = deduplicatedTaskTitles(from: payload.tasks)

        guard !titles.isEmpty else {
            throw CodexTaskIdeaError.invalidResponse
        }

        return titles
    }

    private var normalizedAPIKey: String? {
        let rawValue = apiKeyStore.apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return rawValue.isEmpty ? nil : rawValue
    }

    private var normalizedModelIdentifier: String? {
        let rawValue = settingsRepository.load().selectedModel
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawValue.isEmpty else {
            return nil
        }

        switch rawValue {
        case "Gemini 1.5 Pro", "Claude 3.7 Sonnet":
            return nil
        default:
            return rawValue
        }
    }

    private func resolvedExecutableDescriptor() throws -> ExecutableDescriptor {
        let snapshot = settingsRepository.load()

        if let manualPath = snapshot.codexExecutablePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !manualPath.isEmpty {
            return ExecutableDescriptor(
                path: manualPath,
                bookmarkData: snapshot.codexExecutableBookmarkData
            )
        }

        guard let detectedPath = executableResolver.resolveExecutablePath() else {
            throw CodexTaskIdeaError.executableNotFound
        }

        return ExecutableDescriptor(path: detectedPath, bookmarkData: nil)
    }

    private func launchConfiguration(
        for executableDescriptor: ExecutableDescriptor,
        arguments: [String]
    ) throws -> LaunchConfiguration {
        let resolvedPath = URL(fileURLWithPath: executableDescriptor.path).resolvingSymlinksInPath().path
        let launchPath = resolvedPath.isEmpty ? executableDescriptor.path : resolvedPath

        if launchPath.hasSuffix(".js") {
            return LaunchConfiguration(
                executablePath: "/usr/bin/env",
                arguments: ["node", launchPath] + arguments
            )
        }

        return LaunchConfiguration(executablePath: launchPath, arguments: arguments)
    }

    private func prepareCodexHomeDirectory() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let codexHomeURL = applicationSupportURL
            .appendingPathComponent("OpenKubbo", isDirectory: true)
            .appendingPathComponent("CodexCLI", isDirectory: true)

        try fileManager.createDirectory(at: codexHomeURL, withIntermediateDirectories: true, attributes: nil)
        return codexHomeURL
    }

    private func writeOutputSchema(to url: URL) throws {
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "tasks": [
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 8,
                    "items": [
                        "type": "string"
                    ]
                ]
            ],
            "required": ["tasks"]
        ]

        let data = try JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func executionArguments(
        schemaURL: URL,
        outputURL: URL,
        prompt: String,
        model: String?
    ) -> [String] {
        var arguments = [
            "exec",
            "--skip-git-repo-check",
            "--sandbox",
            "read-only",
            "--output-schema",
            schemaURL.path,
            "--output-last-message",
            outputURL.path,
            "--color",
            "never"
        ]

        if let model {
            arguments.append(contentsOf: ["--model", model])
        }

        arguments.append(prompt)
        return arguments
    }

    private func executionEnvironment(codexHomeURL: URL, apiKey: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = codexHomeURL.path
        environment["OPENAI_API_KEY"] = apiKey
        environment["PATH"] = effectiveExecutionPATH
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
        Return JSON that matches the provided schema and nothing else.

        Rules:
        - Keep the same language as the user's idea.
        - Each task must be independent and specific.
        - Use plain text only.
        - Do not number the tasks.
        - Do not include headings, notes, or explanations.
        - Favor short titles that fit naturally in a compact task card.

        Idea:
        \(idea)
        """
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

    private func normalizedCommandOutput(stderr: String, stdout: String) -> String {
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedError.isEmpty {
            return trimmedError
        }

        let trimmedOutput = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOutput.isEmpty {
            return trimmedOutput
        }

        return "Codex CLI failed to generate tasks."
    }

    private func withSecurityScopedExecutableAccess<T>(
        bookmarkData: Data?,
        operation: () async throws -> T
    ) async throws -> T {
        guard let bookmarkData else {
            return try await operation()
        }

        var isStale = false
        let executableURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        let hasSecurityAccess = executableURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
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
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            var stdinPipe: Pipe?
            if standardInputData != nil {
                let pipe = Pipe()
                process.standardInput = pipe
                stdinPipe = pipe
            }

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()

                if let standardInputData,
                   let stdinPipe {
                    stdinPipe.fileHandleForWriting.write(standardInputData)
                    stdinPipe.fileHandleForWriting.closeFile()
                }
            } catch {
                continuation.resume(
                    throwing: CodexTaskIdeaError.commandFailed(
                        error.localizedDescription.isEmpty
                            ? "Failed to execute Codex CLI."
                            : error.localizedDescription
                    )
                )
            }
        }
    }
}
