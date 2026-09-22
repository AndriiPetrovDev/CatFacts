import Foundation

@MainActor
final class FactDetailsViewModel {
    let title = "Cat Fact"
    let fact: CatFact

    var text: String { fact.text }
    var isVerified: Bool { fact.isVerified }

    init(fact: CatFact) {
        self.fact = fact
    }
}
