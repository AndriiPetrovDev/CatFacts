import XCTest
@testable import CatFacts

final class FactsListViewModelTests: XCTestCase {
    @MainActor
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

    @MainActor
    func testEmptyResponseProducesLoadedEmptyList() async {
        let service = SequentialFactsServiceStub(responses: [.success([])])
        let viewModel = FactsListViewModel(factsService: service)

        await viewModel.loadFacts()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    @MainActor
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

    @MainActor
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
        @MainActor
        func testStubServiceFailureReachesScreenAndCanBeRetried() async {
            let service = FactsServiceStub(fetchFactsResponse: .failure(.httpStatus(503)))
            let dependencies = PreviewAppDependencies(factsService: service)
            let viewModel = FactsListViewModel(factsService: dependencies.factsService)
            var states: [FactsListViewModel.State] = []
            viewModel.onStateChange = { states.append($0) }

            await viewModel.loadFacts()
            await viewModel.loadFacts()

            let errorState = FactsListViewModel.State.failed("The server is temporarily unavailable. Please try again.")
            XCTAssertEqual(states, [.loading, errorState, .loading, errorState])
            XCTAssertEqual(viewModel.state, errorState)
            XCTAssertTrue(viewModel.items.isEmpty)
        }
    #endif

    @MainActor
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

    @MainActor
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

    private func makeFact(id: String) -> CatFact {
        CatFact(id: id, text: "A fact about cats.", createdAt: Date(timeIntervalSince1970: 0), isVerified: true)
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
