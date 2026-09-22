import Foundation

protocol FactsServiceProtocol: AnyObject, Sendable {
    /// Throws FactsServiceError, HTTPClientError, or CancellationError.
    func fetchFacts() async throws -> [CatFact]
}
