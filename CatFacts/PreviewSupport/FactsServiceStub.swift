#if DEBUG
    final class FactsServiceStub: FactsServiceProtocol {
        enum FetchFactsResponse: Sendable {
            case success([CatFact])
            case failure(HTTPClientError)
            case loading
        }

        private let fetchFactsResponse: FetchFactsResponse

        init(fetchFactsResponse: FetchFactsResponse) {
            self.fetchFactsResponse = fetchFactsResponse
        }

        func fetchFacts() async throws -> [CatFact] {
            try Task.checkCancellation()

            switch fetchFactsResponse {
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
