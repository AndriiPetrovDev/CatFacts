import Foundation

@MainActor
final class FactDetailsViewModel {
    let fact: CatFact
    let localization: Localization

    var title: String { localization[.factTitle] }
    var text: String { fact.text }
    var isVerified: Bool { fact.isVerified }
    var isNew: Bool { fact.isNew }

    init(fact: CatFact, localization: Localization = Localization()) {
        self.fact = fact
        self.localization = localization
    }
}
