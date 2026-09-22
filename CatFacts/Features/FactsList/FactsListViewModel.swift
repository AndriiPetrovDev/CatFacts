import Foundation

@MainActor
final class FactsListViewModel {
    let items: [String]
    var onSelectFact: ((String) -> Void)?

    init(items: [String]) {
        self.items = items
    }

    func selectFact(_ title: String) {
        onSelectFact?(title)
    }
}
