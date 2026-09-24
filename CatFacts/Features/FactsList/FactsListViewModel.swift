import Foundation
import Algorithms

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

    var canSearch: Bool {
        state == .loaded && !facts.isEmpty
    }

    private(set) var searchQuery = ""
    private(set) var searchFilters: Set<SearchFilter> = []
    private(set) var state: State = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((State) -> Void)?
    var onSelectFact: ((CatFact) -> Void)?

    let localization: Localization

    private let factsService: any FactsServiceProtocol
    private var facts: [CatFact] = []

    init(factsService: any FactsServiceProtocol, localization: Localization = Localization()) {
        self.factsService = factsService
        self.localization = localization
    }

    func loadFacts() async {
        guard state != .loading, !Task.isCancelled else { return }

        let previousState = state
        state = .loading

        do {
            let facts = try await factsService.fetchFacts()
            try Task.checkCancellation()

            self.facts = facts.uniqued(on: \.id)
            state = .loaded
        } catch is CancellationError {
            state = previousState
        } catch {
            state = Task.isCancelled ? previousState : .failed(message(for: error))
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

    private func message(for error: Error) -> String {
        guard let error = error as? HTTPClientError else {
            return localization[.genericError]
        }

        switch error {
        case .transport(.notConnectedToInternet):
            return localization[.offlineError]
        case .transport(.timedOut):
            return localization[.timeoutError]
        case .httpStatus(let statusCode) where (500 ..< 600).contains(statusCode):
            return localization[.serverError]
        default:
            return localization[.genericError]
        }
    }
}
