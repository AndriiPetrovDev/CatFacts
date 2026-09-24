import Foundation

@MainActor
final class FactsListViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum SearchFilter: Int {
        case verified
        case new
    }

    var items: [CatFact] {
        facts.filter { fact in
            (searchQuery.isEmpty || fact.text.localizedCaseInsensitiveContains(searchQuery))
                && (!searchFilters.contains(.verified) || fact.isVerified)
                && (!searchFilters.contains(.new) || fact.isNew)
        }
    }

    var hasActiveFilters: Bool {
        !searchQuery.isEmpty || !searchFilters.isEmpty
    }

    private(set) var searchQuery = ""
    private(set) var searchFilters: Set<SearchFilter> = []
    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((State) -> Void)?
    var onSelectFact: ((CatFact) -> Void)?

    private let factsService: any FactsServiceProtocol
    private var facts: [CatFact] = []

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

            self.facts = facts
            state = .loaded
        } catch is CancellationError {
            state = previousState
        } catch {
            state = Task.isCancelled ? previousState : .failed(Self.message(for: error))
        }
    }

    func updateSearchQuery(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchQuery != query else { return }
        searchQuery = query
        if state == .loaded {
            onStateChange?(state)
        }
    }

    func toggleSearchFilter(_ filter: SearchFilter) {
        if !searchFilters.insert(filter).inserted {
            searchFilters.remove(filter)
        }
        if state == .loaded {
            onStateChange?(state)
        }
    }

    func fact(withID id: CatFact.ID) -> CatFact? {
        facts.first { $0.id == id }
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
        case .httpStatus(let statusCode) where (500 ..< 600).contains(statusCode):
            return "The server is temporarily unavailable. Please try again."
        default:
            return "Couldn't load facts. Please try again."
        }
    }
}
