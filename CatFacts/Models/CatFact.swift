import Foundation

struct CatFact: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let createdAt: Date
    let isVerified: Bool

    var isNew: Bool {
        isNew(relativeTo: Date())
    }

    func isNew(relativeTo now: Date) -> Bool {
        let freshnessInterval: TimeInterval = 90 * 24 * 60 * 60
        return createdAt >= now.addingTimeInterval(-freshnessInterval)
    }
}
