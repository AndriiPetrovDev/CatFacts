import UIKit

@MainActor
protocol ScreenFactoryProtocol {
    func makeFactsList(onSelectFact: @escaping (CatFact) -> Void) -> UIViewController
    func makeFactDetails(fact: CatFact) -> UIViewController
}
