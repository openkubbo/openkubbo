import Testing
@testable import OpenKubbo

@MainActor
struct MenuBarViewModelTests {
    @Test
    func exposesExpectedMenuOrder() {
        let viewModel = MenuBarViewModel()

        #expect(viewModel.items.map(\.id) == [
            "theme",
            "new-task",
            "repository",
            "terminal",
            "agent",
            "settings"
        ])
    }

    @Test
    func containsSettingsAction() {
        let viewModel = MenuBarViewModel()

        #expect(viewModel.items.contains(where: { $0.action == .openSettings }))
    }
}
