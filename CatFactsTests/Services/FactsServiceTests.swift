import XCTest
@testable import CatFacts

final class FactsServiceTests: XCTestCase {
    private let baseURL = "https://catfacts.test/"

    func testDecodesProvidedResponseIntoDomainModels() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "FactsResponse", withExtension: "json"))
        let client = try HTTPClientStub(result: .success(Data(contentsOf: url)))
        let service = FactsService(httpClient: client, baseURL: baseURL)

        let facts = try await service.fetchFacts()

        XCTAssertEqual(facts.count, 50)
        XCTAssertEqual(facts.first?.id, "66ac00000000000000000001")
        XCTAssertEqual(facts.first?.createdAt, Date(timeIntervalSince1970: 1_656_494_100))
        XCTAssertEqual(facts.first?.isVerified, true)
        XCTAssertEqual(facts.last?.id, "66ac00000000000000000032")
        XCTAssertEqual(facts.last?.isVerified, false)
    }

    func testUsesGETAndRequestsJSON() async throws {
        let client = HTTPClientStub(result: .success(Data("[]".utf8)))
        let service = FactsService(httpClient: client, baseURL: baseURL)

        let facts = try await service.fetchFacts()
        let requests = await client.requests
        let request = try XCTUnwrap(requests.first)

        XCTAssertTrue(facts.isEmpty)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.url?.absoluteString, "https://catfacts.test/18962a8a5d00e62a8d2a")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testKeepsListPathWhenBaseURLChanges() async throws {
        let cases = [
            ("https://api.npoint.io/", "https://api.npoint.io/18962a8a5d00e62a8d2a"),
            ("https://debug.catfacts.test", "https://debug.catfacts.test/18962a8a5d00e62a8d2a"),
            ("https://debug.catfacts.test/api/v1", "https://debug.catfacts.test/api/v1/18962a8a5d00e62a8d2a"),
            ("https://debug.catfacts.test/api/v1/", "https://debug.catfacts.test/api/v1/18962a8a5d00e62a8d2a")
        ]

        for (baseURL, expectedURL) in cases {
            let client = HTTPClientStub(result: .success(Data("[]".utf8)))
            let service = FactsService(httpClient: client, baseURL: baseURL)

            _ = try await service.fetchFacts()
            let requests = await client.requests
            let request = try XCTUnwrap(requests.first)

            XCTAssertEqual(request.url?.absoluteString, expectedURL)
        }
    }

    func testOnlyTrueIsVerified() async throws {
        let statuses: [[String: Any]] = [["verified": true], ["verified": false], ["verified": NSNull()], [:]]
        let records = statuses.enumerated().map { index, status in
            var fact = validFact()
            fact["_id"] = "fact-\(index)"
            fact["status"] = status
            return fact
        }
        let data = try JSONSerialization.data(withJSONObject: records)
        let service = FactsService(httpClient: HTTPClientStub(result: .success(data)), baseURL: baseURL)

        let facts = try await service.fetchFacts()

        XCTAssertEqual(facts.map(\.isVerified), [true, false, false, false])
    }

    func testRejectsInvalidRequiredFieldsInsteadOfDroppingRecords() async throws {
        let invalidFields: [(String, Any?)] = [
            ("_id", nil),
            ("text", nil),
            ("text", NSNull()),
            ("createdAt", nil),
            ("createdAt", "not-a-date"),
            ("status", nil),
            ("status", NSNull()),
            ("status", ["verified": "true"])
        ]

        for (key, value) in invalidFields {
            var invalidFact = validFact()
            invalidFact[key] = value
            let data = try JSONSerialization.data(withJSONObject: [validFact(), invalidFact])
            let service = FactsService(httpClient: HTTPClientStub(result: .success(data)), baseURL: baseURL)

            do {
                _ = try await service.fetchFacts()
                XCTFail("Expected a decoding error for \(key)")
            } catch FactsServiceError.decoding(_) {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsEmptyBodyMalformedJSONAndNonArrayResponse() async {
        for body in ["", "not JSON", "{}"] {
            let client = HTTPClientStub(result: .success(Data(body.utf8)))
            let service = FactsService(httpClient: client, baseURL: baseURL)

            do {
                _ = try await service.fetchFacts()
                XCTFail("Expected a decoding error")
            } catch FactsServiceError.decoding(_) {
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPreservesHTTPClientErrors() async {
        let client = HTTPClientStub(result: .failure(HTTPClientError.httpStatus(503)))
        let service = FactsService(httpClient: client, baseURL: baseURL)

        do {
            _ = try await service.fetchFacts()
            XCTFail("Expected an HTTP error")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .httpStatus(503))
        }
    }

    func testInvalidBaseURLDoesNotStartRequest() async {
        let client = HTTPClientStub(result: .success(Data("[]".utf8)))
        let service = FactsService(httpClient: client, baseURL: "file:///facts.json")

        do {
            _ = try await service.fetchFacts()
            XCTFail("Expected a base URL error")
        } catch FactsServiceError.invalidBaseURL {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let requests = await client.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testCancelledTaskDoesNotStartRequest() async {
        let client = HTTPClientStub(result: .success(Data("[]".utf8)))
        let service = FactsService(httpClient: client, baseURL: baseURL)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.fetchFacts()
        }

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let requests = await client.requests
        XCTAssertTrue(requests.isEmpty)
    }

    private func validFact() -> [String: Any] {
        [
            "_id": "fact-1",
            "text": "A sample cat fact.",
            "createdAt": "2022-06-29T09:15:00 +0000",
            "status": ["verified": true, "sentCount": 1],
            "unknownField": "ignored"
        ]
    }
}

private actor HTTPClientStub: HTTPClientProtocol {
    private let result: Result<Data, Error>
    private(set) var requests: [URLRequest] = []

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func send(_ request: URLRequest) async throws -> Data {
        requests.append(request)
        return try result.get()
    }
}
