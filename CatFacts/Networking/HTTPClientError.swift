import Foundation

enum HTTPClientError: Error, Equatable {
    case transport(URLError.Code)
    case httpStatus(Int)
    case invalidResponse
}
