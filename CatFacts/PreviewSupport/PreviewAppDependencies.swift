#if DEBUG
    final class PreviewAppDependencies: AppDependenciesProtocol {
        let factsService: any FactsServiceProtocol

        init(factsService: any FactsServiceProtocol) {
            self.factsService = factsService
        }
    }
#endif
