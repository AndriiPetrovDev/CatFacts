import Foundation

@MainActor
final class FactDetailsViewModel {
    let fact: CatFact

    var title: String { String(localized: "fact.title") }
    var text: String { fact.text }
    var isVerified: Bool { fact.isVerified }
    var isNew: Bool { fact.isNew }

    init(fact: CatFact) {
        self.fact = fact
    }
}
