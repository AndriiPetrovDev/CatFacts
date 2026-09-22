import Foundation

@MainActor
final class FactDetailsViewModel {
    let title = "Cat Fact"
    let fact: CatFact

    var text: String { fact.text }

    init(fact: CatFact) {
        self.fact = fact
    }
}
