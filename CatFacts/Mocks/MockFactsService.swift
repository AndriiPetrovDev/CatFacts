#if DEBUG
    final class MockFactsService: FactsServiceProtocol {
        private let result: Result<[CatFact], HTTPClientError>

        init(result: Result<[CatFact], HTTPClientError>) {
            self.result = result
        }

        func fetchFacts() async throws -> [CatFact] {
            try Task.checkCancellation()
            return try result.get()
        }
    }
#endif
