#if DEBUG
    final class MockAppDependencies: AppDependenciesProtocol {
        let factsService: any FactsServiceProtocol

        private init(response: MockFactsService.Response) {
            factsService = MockFactsService(response: response)
        }

        static func failure(error: HTTPClientError = .httpStatus(503)) -> MockAppDependencies {
            MockAppDependencies(response: .failure(error))
        }

        static func empty() -> MockAppDependencies {
            MockAppDependencies(response: .success([]))
        }

        static func loading() -> MockAppDependencies {
            MockAppDependencies(response: .loading)
        }
    }
#endif
