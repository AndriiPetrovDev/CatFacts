import UIKit

@MainActor
final class AppCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let screenFactory: any ScreenFactoryProtocol

    init(navigationController: UINavigationController, screenFactory: any ScreenFactoryProtocol) {
        self.navigationController = navigationController
        self.screenFactory = screenFactory
    }

    func start() {
        let viewController = screenFactory.makeFactsList { [weak self] fact in
            self?.showFactDetails(fact: fact)
        }

        navigationController.setViewControllers([viewController], animated: false)
    }

    private func showFactDetails(fact: CatFact) {
        let viewController = screenFactory.makeFactDetails(fact: fact)
        navigationController.pushViewController(viewController, animated: true)
    }
}
