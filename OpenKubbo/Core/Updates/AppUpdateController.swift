import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    let isConfigured: Bool

    private let updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        let feedURL = Self.trimmedInfoValue(forKey: "SUFeedURL", bundle: bundle)
        let publicKey = Self.trimmedInfoValue(forKey: "SUPublicEDKey", bundle: bundle)
        let isConfigured = !feedURL.isEmpty && !publicKey.isEmpty

        self.isConfigured = isConfigured

        guard isConfigured else {
            self.updaterController = nil
            return
        }

        let updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        self.updaterController = updaterController
        self.canCheckForUpdates = updaterController.updater.canCheckForUpdates

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    private static func trimmedInfoValue(forKey key: String, bundle: Bundle) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return ""
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
