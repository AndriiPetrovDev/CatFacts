import UIKit

@MainActor
final class ScreenFactory: ScreenFactoryProtocol {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makeFactsList(onSelectFact: @escaping (CatFact) -> Void) -> UIViewController {
        let viewModel = FactsListViewModel(factsService: dependencies.factsService)
        viewModel.onSelectFact = onSelectFact
        return FactsListViewController(viewModel: viewModel)
    }

    func makeFactDetails(fact: CatFact) -> UIViewController {
        let viewModel = FactDetailsViewModel(fact: fact)
        return FactDetailsViewController(viewModel: viewModel)
    }
}
