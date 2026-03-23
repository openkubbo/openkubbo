import Foundation

final class CodexCLITaskIdeaGenerator: TaskIdeaGenerating {
    private struct TaskIdeaPayload: Decodable {
        let tasks: [String]
    }

    private struct OpenAIResponsesRequest: Encodable {
        struct TextConfiguration: Encodable {
            struct OutputFormat: Encodable {
                let type: String
                let name: String
                let strict: Bool
                let schema: Schema
            }

            let format: OutputFormat
        }

        struct Schema: Encodable {
            let type: String
            let additionalProperties: Bool
            let properties: [String: SchemaValue]
            let required: [String]
        }

        struct SchemaValue: Encodable {
            let type: String
            let minItems: Int?
            let maxItems: Int?
            let items: SchemaItems?

            init(type: String, minItems: Int? = nil, maxItems: Int? = nil, items: SchemaItems? = nil) {
                self.type = type
                self.minItems = minItems
                self.maxItems = maxItems
                self.items = items
            }
        }

        struct SchemaItems: Encodable {
            let type: String
        }

        let model: String
        let input: String
        let text: TextConfiguration
    }

    private struct OpenAIResponsesResponse: Decodable {
        struct OutputItem: Decodable {
            struct ContentItem: Decodable {
                let type: String
                let text: String?
                let refusal: String?
            }

            let type: String
            let content: [ContentItem]?
        }

        let output: [OutputItem]
    }

    private struct OpenAIErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String
        }

        let error: APIError
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
    private let nodeExecutableResolver: NodeRuntimeExecutableResolving
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession

    init(
        settingsRepository: SettingsRepository,
        apiKeyStore: CodexAPIKeyStoring,
        executableResolver: CodexCLIExecutableResolving,
        nodeExecutableResolver: NodeRuntimeExecutableResolving,
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        session: URLSession = .shared
    ) {
        self.settingsRepository = settingsRepository
        self.apiKeyStore = apiKeyStore
        self.executableResolver = executableResolver
        self.nodeExecutableResolver = nodeExecutableResolver
        self.fileManager = fileManager
        self.decoder = decoder
        self.encoder = encoder
        self.session = session
    }

    func generateTasks(from idea: String) async throws -> [String] {
        let trimmedIdea = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdea.isEmpty else {
            throw CodexTaskIdeaError.invalidResponse
        }

        if canUseLocalCodexCLI,
           let executableDescriptor = try localCodexExecutableDescriptorIfAvailable() {
            let nodeExecutableDescriptor = try resolvedNodeExecutableDescriptor(for: executableDescriptor)
            let titles = try await generateTasksViaLocalCodexCLI(
                from: trimmedIdea,
                executableDescriptor: executableDescriptor,
                nodeExecutableDescriptor: nodeExecutableDescriptor
            )

            guard !titles.isEmpty else {
                throw CodexTaskIdeaError.invalidResponse
            }

            return titles
        }

        guard let apiKey = normalizedAPIKey else {
            throw CodexTaskIdeaError.missingAPIKey
        }

        let payload = try await generateTasksViaOpenAIAPI(from: trimmedIdea, apiKey: apiKey)
        let titles = deduplicatedTaskTitles(from: payload.tasks)

        guard !titles.isEmpty else {
            throw CodexTaskIdeaError.invalidResponse
        }

        return titles
    }

    private var canUseLocalCodexCLI: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
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

    private var fallbackAPIModelIdentifier: String {
        normalizedModelIdentifier ?? "gpt-5"
    }

    private func localCodexExecutableDescriptorIfAvailable() throws -> ExecutableDescriptor? {
        do {
            return try resolvedExecutableDescriptor()
        } catch CodexTaskIdeaError.executableNotFound {
            return nil
        } catch {
            throw error
        }
    }

    private func generateTasksViaLocalCodexCLI(
        from idea: String,
        executableDescriptor: ExecutableDescriptor,
        nodeExecutableDescriptor: ExecutableDescriptor?
    ) async throws -> [String] {
        guard !executableDescriptor.path.isEmpty else {
            throw CodexTaskIdeaError.executableNotFound
        }

        let workingDirectoryURL = try prepareCodexHomeDirectory()
        let tempDirectoryURL = workingDirectoryURL.appendingPathComponent("temp", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let requestID = UUID().uuidString.lowercased()
        let schemaURL = tempDirectoryURL.appendingPathComponent("idea-schema-\(requestID).json")
        let outputURL = tempDirectoryURL.appendingPathComponent("idea-output-\(requestID).json")
        defer {
            try? fileManager.removeItem(at: schemaURL)
            try? fileManager.removeItem(at: outputURL)
        }

        try writeOutputSchema(to: schemaURL)

        let generationLaunchConfiguration = try launchConfiguration(
            for: executableDescriptor,
            nodeExecutableDescriptor: nodeExecutableDescriptor,
            arguments: executionArguments(
                schemaURL: schemaURL,
                outputURL: outputURL,
                prompt: prompt(for: idea),
                model: normalizedModelIdentifier
            )
        )

        let generationResult = try await withSecurityScopedExecutableAccess(
            descriptors: [executableDescriptor, nodeExecutableDescriptor].compactMap { $0 }
        ) {
            try await runProcess(
                executablePath: generationLaunchConfiguration.executablePath,
                arguments: generationLaunchConfiguration.arguments,
                currentDirectoryURL: workingDirectoryURL,
                environment: executionEnvironment()
            )
        }

        guard generationResult.exitCode == 0 else {
            throw CodexTaskIdeaError.commandFailed(
                normalizedLocalCLIError(stderr: generationResult.stderr, stdout: generationResult.stdout)
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

        return deduplicatedTaskTitles(from: payload.tasks)
    }

    private func generateTasksViaOpenAIAPI(from idea: String, apiKey: String) async throws -> TaskIdeaPayload {
        let schema = OpenAIResponsesRequest.Schema(
            type: "object",
            additionalProperties: false,
            properties: [
                "tasks": OpenAIResponsesRequest.SchemaValue(
                    type: "array",
                    minItems: 2,
                    maxItems: 8,
                    items: OpenAIResponsesRequest.SchemaItems(type: "string")
                )
            ],
            required: ["tasks"]
        )

        let requestBody = OpenAIResponsesRequest(
            model: fallbackAPIModelIdentifier,
            input: prompt(for: idea),
            text: .init(
                format: .init(
                    type: "json_schema",
                    name: "task_cards",
                    strict: true,
                    schema: schema
                )
            )
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodexTaskIdeaError.commandFailed("OpenAI returned an invalid HTTP response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorEnvelope = try? decoder.decode(OpenAIErrorEnvelope.self, from: data) {
                throw CodexTaskIdeaError.commandFailed(errorEnvelope.error.message)
            }

            throw CodexTaskIdeaError.commandFailed(
                "OpenAI request failed with status \(httpResponse.statusCode)."
            )
        }

        let responsesPayload: OpenAIResponsesResponse
        do {
            responsesPayload = try decoder.decode(OpenAIResponsesResponse.self, from: data)
        } catch {
            throw CodexTaskIdeaError.invalidResponse
        }

        let outputText = responsesPayload.output
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !outputText.isEmpty else {
            if let refusalMessage = responsesPayload.output
                .flatMap({ $0.content ?? [] })
                .first(where: { $0.type == "refusal" })?
                .refusal,
               !refusalMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw CodexTaskIdeaError.commandFailed(refusalMessage)
            }

            throw CodexTaskIdeaError.invalidResponse
        }

        guard let responseData = outputText.data(using: .utf8) else {
            throw CodexTaskIdeaError.invalidResponse
        }

        do {
            return try decoder.decode(TaskIdeaPayload.self, from: responseData)
        } catch {
            throw CodexTaskIdeaError.invalidResponse
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

    private func resolvedNodeExecutableDescriptor(
        for codexExecutableDescriptor: ExecutableDescriptor
    ) throws -> ExecutableDescriptor? {
        guard requiresNodeRuntime(for: codexExecutableDescriptor) else {
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
            throw CodexTaskIdeaError.nodeRuntimeNotFound
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

    private func executionEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
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

        return "Codex CLI failed to generate tasks."
    }

    private func normalizedLocalCLIError(stderr: String, stdout: String) -> String {
        let message = normalizedCommandOutput(stderr: stderr, stdout: stdout)
        let normalizedMessage = message.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )

        if normalizedMessage.contains("login required") ||
            normalizedMessage.contains("please login") ||
            normalizedMessage.contains("please log in") ||
            normalizedMessage.contains("not logged in") ||
            normalizedMessage.contains("not authenticated") ||
            normalizedMessage.contains("auth") {
            return "Codex CLI is installed, but your local session is not authenticated. In Terminal, run `codex login` and choose ChatGPT."
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
