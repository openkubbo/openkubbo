import Foundation

final class ProviderBackedTaskIdeaGenerator: TaskIdeaGenerating {
    private let settingsRepository: SettingsRepository
    private let openAITaskIdeaGenerator: TaskIdeaGenerating
    private let googleTaskIdeaGenerator: TaskIdeaGenerating

    init(
        settingsRepository: SettingsRepository,
        openAITaskIdeaGenerator: TaskIdeaGenerating,
        googleTaskIdeaGenerator: TaskIdeaGenerating
    ) {
        self.settingsRepository = settingsRepository
        self.openAITaskIdeaGenerator = openAITaskIdeaGenerator
        self.googleTaskIdeaGenerator = googleTaskIdeaGenerator
    }

    func generateTasks(from idea: String) async throws -> [String] {
        switch settingsRepository.load().taskGenerationProvider {
        case .openAI:
            return try await openAITaskIdeaGenerator.generateTasks(from: idea)
        case .google:
            return try await googleTaskIdeaGenerator.generateTasks(from: idea)
        }
    }
}
