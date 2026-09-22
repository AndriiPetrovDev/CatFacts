import UIKit

@MainActor
final class AppCoordinator: Coordinator {
    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let viewModel = FactsListViewModel(items: (1 ... 12).map { "Cat fact \($0)" })
        viewModel.onSelectFact = { [weak self] title in
            self?.showFactDetails(title: title)
        }

        let viewController = FactsListViewController(viewModel: viewModel)
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.setViewControllers([viewController], animated: false)
    }

    private func showFactDetails(title: String) {
        let viewModel = FactDetailsViewModel(title: title)
        let viewController = FactDetailsViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }
}
