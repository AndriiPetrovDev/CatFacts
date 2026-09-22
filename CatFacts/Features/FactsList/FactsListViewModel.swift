import Foundation

@MainActor
final class FactsListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var items: [CatFact] = []
    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((State) -> Void)?
    var onSelectFact: ((CatFact) -> Void)?

    private let factsService: any FactsServiceProtocol

    init(factsService: any FactsServiceProtocol) {
        self.factsService = factsService
    }

    func loadFacts() async {
        guard state != .loading, !Task.isCancelled else { return }

        let previousState = state
        state = .loading

        do {
            let facts = try await factsService.fetchFacts()
            try Task.checkCancellation()

            guard Set(facts.map(\.id)).count == facts.count else {
                state = .failed("Couldn't load facts. Please try again.")
                return
            }

            items = facts
            state = .loaded
        } catch is CancellationError {
            state = previousState
        } catch {
            state = Task.isCancelled ? previousState : .failed(Self.message(for: error))
        }
    }

    func fact(withID id: CatFact.ID) -> CatFact? {
        items.first { $0.id == id }
    }

    func selectFact(withID id: CatFact.ID) {
        guard let fact = fact(withID: id) else { return }
        onSelectFact?(fact)
    }

    private static func message(for error: Error) -> String {
        guard let error = error as? HTTPClientError else {
            return "Couldn't load facts. Please try again."
        }

        switch error {
        case .transport(.notConnectedToInternet):
            return "You're offline. Check your internet connection and try again."
        case .transport(.timedOut):
            return "The request timed out. Please try again."
        default:
            return "Couldn't load facts. Please try again."
        }
    }
}
