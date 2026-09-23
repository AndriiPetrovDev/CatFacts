import Foundation

#if DEBUG
    final class MockHTTPClient: HTTPClientProtocol {
        private let error: HTTPClientError

        init(error: HTTPClientError = .httpStatus(503)) {
            self.error = error
        }

        func send(_ request: URLRequest) async throws -> Data {
            try Task.checkCancellation()
            throw error
        }
    }
#endif
