import Foundation

enum FactsServiceError: Error {
    case invalidBaseURL
    case decoding(DecodingError)
}
