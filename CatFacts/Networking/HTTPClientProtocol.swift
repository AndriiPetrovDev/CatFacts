import Foundation

protocol HTTPClientProtocol: Sendable {
    /// Returns the body of a successful HTTP response. Throws HTTPClientError or CancellationError.
    func send(_ request: URLRequest) async throws -> Data
}
