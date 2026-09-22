import Foundation

struct CatFact: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let createdAt: Date
    let isVerified: Bool
}
