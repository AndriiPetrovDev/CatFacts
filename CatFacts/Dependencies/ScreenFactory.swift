import UIKit

@MainActor
final class ScreenFactory: ScreenFactoryProtocol {
    private let dependencies: any AppDependenciesProtocol

    init(dependencies: any AppDependenciesProtocol) {
        self.dependencies = dependencies
    }

    func makeFactsList(onSelectFact: @escaping (CatFact) -> Void) -> UIViewController {
        let viewModel = FactsListViewModel(factsService: dependencies.factsService)
        viewModel.onSelectFact = onSelectFact
        if #available(iOS 26.0, *) {
            return FactsListViewController(viewModel: viewModel)
        }
        return FactsListLegacyViewController(viewModel: viewModel)
    }

    func makeFactDetails(fact: CatFact) -> UIViewController {
        let viewModel = FactDetailsViewModel(fact: fact)
        return FactDetailsViewController(viewModel: viewModel)
    }
}
