import Foundation

@MainActor
final class FactDetailsViewModel {
    let title: String
    let text = "Details for this fact will appear here."

    init(title: String) {
        self.title = title
    }
}
