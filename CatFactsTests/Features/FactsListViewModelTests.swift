import XCTest
@testable import CatFacts

@MainActor
final class FactsListViewModelTests: XCTestCase {
    func testLoadsServiceFactsAndNotifiesScreen() async {
        let facts = [makeFact(id: "first"), makeFact(id: "second")]
        let service = SequentialFactsServiceStub(responses: [.success(facts)])
        let viewModel = FactsListViewModel(factsService: service)
        var states: [FactsListViewModel.State] = []
        viewModel.onStateChange = { states.append($0) }

        await viewModel.loadFacts()

        XCTAssertEqual(states, [.loading, .loaded])
        XCTAssertEqual(viewModel.items, facts)
        let requestCount = await service.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testEmptyResponseProducesLoadedEmptyList() async {
        let service = SequentialFactsServiceStub(responses: [.success([])])
        let viewModel = FactsListViewModel(factsService: service)

        await viewModel.loadFacts()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testCanRetryAfterNetworkFailure() async {
        let facts = [makeFact(id: "first")]
        let service = SequentialFactsServiceStub(responses: [
            .failure(HTTPClientError.transport(.notConnectedToInternet)),
            .success(facts)
        ])
        let viewModel = FactsListViewModel(factsService: service)

        await viewModel.loadFacts()

        guard case .failed(let message) = viewModel.state else {
            return XCTFail("Expected a retryable error")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(viewModel.items.isEmpty)

        await viewModel.loadFacts()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.items, facts)
        let requestCount = await service.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func testCancellationRestoresPreviouslyLoadedFacts() async {
        let facts = [makeFact(id: "first")]
        let service = SequentialFactsServiceStub(responses: [.success(facts), .failure(CancellationError())])
        let viewModel = FactsListViewModel(factsService: service)

        await viewModel.loadFacts()
        await viewModel.loadFacts()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.items, facts)
    }

    #if DEBUG
        func testStubServiceFailureReachesScreenAndCanBeRetried() async {
            let facts = [makeFact(id: "recovered")]
            let service = FactsServiceStub(fetchFactsResponses: [.failure(.httpStatus(503)), .success(facts)])
            let dependencies = PreviewAppDependencies(factsService: service)
            let viewModel = FactsListViewModel(factsService: dependencies.factsService)
            var states: [FactsListViewModel.State] = []
            viewModel.onStateChange = { states.append($0) }

            await viewModel.loadFacts()
            await viewModel.loadFacts()

            let errorState = FactsListViewModel.State.failed(String(localized: "error.server"))
            XCTAssertEqual(states, [.loading, errorState, .loading, .loaded])
            XCTAssertEqual(viewModel.state, .loaded)
            XCTAssertEqual(viewModel.items, facts)
        }
    #endif

    func testMapsErrorsToDistinctUserFacingMessages() async {
        let cases: [(error: Error, message: String)] = [
            (HTTPClientError.transport(.notConnectedToInternet), String(localized: "error.offline")),
            (HTTPClientError.transport(.timedOut), String(localized: "error.timeout")),
            (HTTPClientError.httpStatus(500), String(localized: "error.server")),
            (HTTPClientError.httpStatus(599), String(localized: "error.server")),
            (HTTPClientError.httpStatus(404), String(localized: "error.generic")),
            (HTTPClientError.invalidResponse, String(localized: "error.generic")),
            (FactsServiceError.invalidBaseURL, String(localized: "error.generic"))
        ]

        for testCase in cases {
            let service = SequentialFactsServiceStub(responses: [.failure(testCase.error)])
            let viewModel = FactsListViewModel(factsService: service)

            await viewModel.loadFacts()

            XCTAssertEqual(viewModel.state, .failed(testCase.message), "Error: \(testCase.error)")
        }
    }

    func testDuplicateIDsKeepFirstOccurrenceAndPreserveOrder() async {
        let first = makeFact(id: "first")
        let second = makeFact(id: "second")
        let duplicate = CatFact(
            id: first.id,
            text: "A different fact with the same ID.",
            createdAt: first.createdAt,
            isVerified: false
        )
        let service = SequentialFactsServiceStub(responses: [.success([first, second, duplicate, second])])
        let viewModel = FactsListViewModel(factsService: service)
        var states: [FactsListViewModel.State] = []
        viewModel.onStateChange = { states.append($0) }

        await viewModel.loadFacts()

        XCTAssertEqual(states, [.loading, .loaded])
        XCTAssertEqual(viewModel.items, [first, second])
        XCTAssertEqual(viewModel.fact(withID: first.id), first)
    }

    func testSelectsFullFactByIDWhenTextsAreIdentical() async {
        let first = makeFact(id: "first")
        let second = makeFact(id: "second")
        let service = SequentialFactsServiceStub(responses: [.success([first, second])])
        let viewModel = FactsListViewModel(factsService: service)
        var selections: [CatFact] = []
        viewModel.onSelectFact = { selections.append($0) }
        await viewModel.loadFacts()

        viewModel.selectFact(withID: second.id)
        viewModel.selectFact(withID: "missing")

        XCTAssertEqual(selections, [second])
    }

    func testSearchMatchesSubstringsIgnoringCaseAndTrimsWhitespace() async {
        let facts = [
            makeFact(id: "first", text: "Cats purr when content."),
            makeFact(id: "second", text: "Cats use their whiskers to sense nearby objects."),
            makeFact(id: "third", text: "Kittens also purr.")
        ]
        let service = SequentialFactsServiceStub(responses: [.success(facts)])
        let viewModel = FactsListViewModel(factsService: service)
        await viewModel.loadFacts()
        let cases: [(query: String, expectedIDs: [String], hasActiveFilters: Bool)] = [
            ("purr", ["first", "third"], true),
            ("PuRr", ["first", "third"], true),
            (" \nPuRr\t ", ["first", "third"], true),
            ("hisk", ["second"], true),
            ("no matching keyword", [], true),
            ("", ["first", "second", "third"], false),
            ("purr", ["first", "third"], true),
            (" \t\n ", ["first", "second", "third"], false)
        ]

        for testCase in cases {
            viewModel.updateSearchQuery(testCase.query)

            XCTAssertEqual(viewModel.items.map(\.id), testCase.expectedIDs, "Query: \(testCase.query.debugDescription)")
            XCTAssertEqual(viewModel.hasActiveFilters, testCase.hasActiveFilters)
            XCTAssertTrue(viewModel.canSearch)
            XCTAssertEqual(viewModel.state, .loaded)
        }
    }

    func testSearchAndFiltersRequireAllActiveCriteria() async {
        let facts = makeSearchFacts()
        let cases: [(query: String, filters: [FactsListViewModel.SearchFilter], expectedIDs: [String])] = [
            ("", [], facts.map(\.id)),
            ("", [.verified], ["new-verified-purr", "new-verified-sleep", "old-verified-purr", "old-verified-sleep"]),
            ("", [.new], ["new-verified-purr", "new-verified-sleep", "new-unverified-purr", "new-unverified-sleep"]),
            ("", [.verified, .new], ["new-verified-purr", "new-verified-sleep"]),
            ("purr", [], ["new-verified-purr", "old-verified-purr", "new-unverified-purr", "old-unverified-purr"]),
            ("purr", [.verified], ["new-verified-purr", "old-verified-purr"]),
            ("purr", [.new], ["new-verified-purr", "new-unverified-purr"]),
            ("purr", [.verified, .new], ["new-verified-purr"]),
            ("no matching keyword", [.verified, .new], [])
        ]

        for testCase in cases {
            let service = SequentialFactsServiceStub(responses: [.success(facts)])
            let viewModel = FactsListViewModel(factsService: service)
            await viewModel.loadFacts()

            viewModel.updateSearchQuery(testCase.query)
            for filter in testCase.filters {
                viewModel.toggleSearchFilter(filter)
            }

            XCTAssertEqual(
                viewModel.items.map(\.id),
                testCase.expectedIDs,
                "Query: \(testCase.query.debugDescription), filters: \(testCase.filters)"
            )
            XCTAssertTrue(viewModel.canSearch)
            XCTAssertEqual(viewModel.state, .loaded)
        }
    }

    func testChangingAndClearingSearchPreservesFiltersUntilTheyAreToggledOff() async {
        let facts = makeSearchFacts()
        let service = SequentialFactsServiceStub(responses: [.success(facts)])
        let viewModel = FactsListViewModel(factsService: service)
        await viewModel.loadFacts()

        viewModel.toggleSearchFilter(.new)
        viewModel.toggleSearchFilter(.verified)
        viewModel.updateSearchQuery("purr")
        XCTAssertEqual(viewModel.items.map(\.id), ["new-verified-purr"])

        viewModel.updateSearchQuery("sleep")
        XCTAssertEqual(viewModel.items.map(\.id), ["new-verified-sleep"])

        viewModel.updateSearchQuery("")
        XCTAssertEqual(viewModel.items.map(\.id), ["new-verified-purr", "new-verified-sleep"])
        XCTAssertTrue(viewModel.hasActiveFilters)

        viewModel.toggleSearchFilter(.verified)
        XCTAssertEqual(viewModel.items.map(\.id), ["new-verified-purr", "new-verified-sleep", "new-unverified-purr", "new-unverified-sleep"])
        XCTAssertTrue(viewModel.hasActiveFilters)

        viewModel.toggleSearchFilter(.new)
        XCTAssertEqual(viewModel.items, facts)
        XCTAssertFalse(viewModel.hasActiveFilters)
    }

    func testSearchAndFilterChangesNotifyScreenWithoutFetchingAgain() async {
        let service = SequentialFactsServiceStub(responses: [.success(makeSearchFacts())])
        let viewModel = FactsListViewModel(factsService: service)
        await viewModel.loadFacts()
        var displayedIDs: [[String]] = []
        viewModel.onStateChange = { [weak viewModel] _ in
            guard let viewModel else { return }
            displayedIDs.append(viewModel.items.map(\.id))
        }

        viewModel.updateSearchQuery("purr")
        viewModel.updateSearchQuery(" \npurr\t ")
        viewModel.toggleSearchFilter(.verified)
        viewModel.toggleSearchFilter(.new)
        viewModel.toggleSearchFilter(.new)

        XCTAssertEqual(displayedIDs, [
            ["new-verified-purr", "old-verified-purr", "new-unverified-purr", "old-unverified-purr"],
            ["new-verified-purr", "old-verified-purr"],
            ["new-verified-purr"],
            ["new-verified-purr", "old-verified-purr"]
        ])
        let requestCount = await service.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    private func makeSearchFacts() -> [CatFact] {
        let now = Date()
        let recentDate = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let oldDate = now.addingTimeInterval(-180 * 24 * 60 * 60)
        return [
            makeFact(id: "new-verified-purr", text: "Cats purr.", createdAt: recentDate),
            makeFact(id: "new-verified-sleep", text: "Cats sleep.", createdAt: recentDate),
            makeFact(id: "old-verified-purr", text: "Cats purr.", createdAt: oldDate),
            makeFact(id: "old-verified-sleep", text: "Cats sleep.", createdAt: oldDate),
            makeFact(id: "new-unverified-purr", text: "Cats purr.", createdAt: recentDate, isVerified: false),
            makeFact(id: "new-unverified-sleep", text: "Cats sleep.", createdAt: recentDate, isVerified: false),
            makeFact(id: "old-unverified-purr", text: "Cats purr.", createdAt: oldDate, isVerified: false),
            makeFact(id: "old-unverified-sleep", text: "Cats sleep.", createdAt: oldDate, isVerified: false)
        ]
    }

    private func makeFact(
        id: String,
        text: String = "A fact about cats.",
        createdAt: Date = Date(timeIntervalSince1970: 0),
        isVerified: Bool = true
    ) -> CatFact {
        CatFact(id: id, text: text, createdAt: createdAt, isVerified: isVerified)
    }
}

private actor SequentialFactsServiceStub: FactsServiceProtocol {
    private enum StubError: Error {
        case unexpectedRequest
    }

    private var responses: [Result<[CatFact], Error>]
    private(set) var requestCount = 0

    init(responses: [Result<[CatFact], Error>]) {
        self.responses = responses
    }

    func fetchFacts() async throws -> [CatFact] {
        requestCount += 1
        guard !responses.isEmpty else { throw StubError.unexpectedRequest }
        return try responses.removeFirst().get()
    }
}
