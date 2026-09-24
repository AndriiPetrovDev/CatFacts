import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let scenarioName = ProcessInfo.processInfo.environment["UI_TEST_SCENARIO"] ?? "facts"
        guard let scenario = Scenario(rawValue: scenarioName) else {
            preconditionFailure("Unknown UI-test scenario: \(scenarioName)")
        }
        let dependencies = PreviewAppDependencies(factsService: scenario.makeFactsService())
        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true
        let coordinator = AppCoordinator(
            navigationController: navigationController,
            screenFactory: ScreenFactory(dependencies: dependencies)
        )
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        self.coordinator = coordinator
        window.rootViewController = navigationController
        coordinator.start()
        window.makeKeyAndVisible()
    }
}

private enum Scenario: String {
    case facts
    case offlineThenSuccess
    case scrolling

    func makeFactsService() -> FactsServiceStub {
        let recentDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let oldDate = Date().addingTimeInterval(-180 * 24 * 60 * 60)
        var facts = [
            CatFactFixtures.make(id: "recent-verified", text: "Cats purr to communicate.", createdAt: recentDate),
            CatFactFixtures.make(id: "old-verified", text: "Some cats purr softly.", createdAt: oldDate),
            CatFactFixtures.make(id: "recent-unverified", text: "Kittens can purr.", createdAt: recentDate, isVerified: false),
            CatFactFixtures.make(id: "other-topic", text: "Cats sleep for much of the day.", createdAt: recentDate)
        ]

        if self == .scrolling {
            facts += (1 ... 30).map { index in
                CatFactFixtures.make(
                    id: "scroll-\(index)",
                    text: "Cats purr in quiet moments. Observation \(index).",
                    createdAt: recentDate
                )
            }
        }

        if self == .offlineThenSuccess {
            return FactsServiceStub(fetchFactsResponses: [
                .failure(.transport(.notConnectedToInternet)),
                .success(facts)
            ])
        }
        return FactsServiceStub(fetchFactsResponse: .success(facts))
    }
}
