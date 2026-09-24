#if DEBUG
    actor FactsServiceStub: FactsServiceProtocol {
        enum FetchFactsResponse: Sendable {
            case success([CatFact])
            case slowInternet([CatFact])
            case failure(HTTPClientError)
            case loading
        }

        private var responses: [FetchFactsResponse]

        init(fetchFactsResponse: FetchFactsResponse) {
            responses = [fetchFactsResponse]
        }

        init(fetchFactsResponses: [FetchFactsResponse]) {
            precondition(!fetchFactsResponses.isEmpty, "A stub requires at least one response.")
            responses = fetchFactsResponses
        }

        func fetchFacts() async throws -> [CatFact] {
            try Task.checkCancellation()

            let response = responses.count > 1 ? responses.removeFirst() : responses[0]
            switch response {
            case .success(let facts):
                return facts

            case .slowInternet(let facts):
                try await Task.sleep(nanoseconds: 2_000_000_000)
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
