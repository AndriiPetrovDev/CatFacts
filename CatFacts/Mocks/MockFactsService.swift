#if DEBUG
    final class MockFactsService: FactsServiceProtocol {
        enum Response: Sendable {
            case success([CatFact])
            case failure(HTTPClientError)
            case loading
        }

        private let response: Response

        init(response: Response) {
            self.response = response
        }

        func fetchFacts() async throws -> [CatFact] {
            try Task.checkCancellation()

            switch response {
            case .success(let facts):
                return facts
            case .failure(let error):
                throw error
            case .loading:
                while true {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                }
            }
        }
    }
#endif
