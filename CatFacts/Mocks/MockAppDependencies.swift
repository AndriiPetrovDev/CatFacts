#if DEBUG
    final class MockAppDependencies: AppDependenciesProtocol {
        let factsService: any FactsServiceProtocol

        private init(result: Result<[CatFact], HTTPClientError>) {
            factsService = MockFactsService(result: result)
        }

        static func failure(error: HTTPClientError = .httpStatus(503)) -> MockAppDependencies {
            MockAppDependencies(result: .failure(error))
        }

        static func empty() -> MockAppDependencies {
            MockAppDependencies(result: .success([]))
        }
    }
#endif
