import Foundation

final class FactsService: FactsServiceProtocol {
    private static let listPath = "18962a8a5d00e62a8d2a"

    private let httpClient: any HTTPClientProtocol
    private let baseURL: String

    init(httpClient: any HTTPClientProtocol, baseURL: String) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    func fetchFacts() async throws -> [CatFact] {
        try Task.checkCancellation()

        guard let url = URL(string: baseURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else {
            throw FactsServiceError.invalidBaseURL
        }

        var request = URLRequest(url: url.appendingPathComponent(Self.listPath))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data = try await httpClient.send(request)
        try Task.checkCancellation()

        do {
            let facts = try Self.makeDecoder().decode([CatFactDTO].self, from: data)
            try Task.checkCancellation()
            return facts.map { $0.toDomain() }
        } catch let error as DecodingError {
            throw FactsServiceError.decoding(error)
        }
    }

    private static func makeDecoder() -> JSONDecoder {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss Z"
        formatter.isLenient = false

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }
}
