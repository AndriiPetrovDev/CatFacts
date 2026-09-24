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
        XCTAssertEqual(facts.first?.createdAt, try makeUTCDate(year: 2022, month: 6, day: 29, hour: 9, minute: 15))
        XCTAssertEqual(facts.first?.isVerified, true)
        XCTAssertEqual(facts.last?.id, "66ac00000000000000000032")
        XCTAssertEqual(facts.last?.isVerified, false)
    }

    func testDecodesAllFieldsFromHardcodedResponse() async throws {
        let facts = try await decodeResponse("[\(validFactJSON)]")

        XCTAssertEqual(facts, try [
            CatFact(
                id: "66ac00000000000000000001",
                text: "Cats can rotate each ear independently and direct it toward a sound without moving their head. This ability helps them pinpoint quiet rustling and other subtle noises with impressive accuracy.",
                createdAt: makeUTCDate(year: 2022, month: 6, day: 29, hour: 9, minute: 15),
                isVerified: true
            )
        ])
    }

    func testDecodesDateOffsetsAsTheSameInstant() async throws {
        let response = #"""
        [
            {
                "_id": "utc",
                "text": "Cats can rotate each ear independently.",
                "status": {"verified": true, "sentCount": 128},
                "createdAt": "2022-06-29T09:15:00 +0000"
            },
            {
                "_id": "east",
                "text": "Cats can rotate each ear independently.",
                "status": {"verified": true, "sentCount": 128},
                "createdAt": "2022-06-29T11:15:00 +0200"
            },
            {
                "_id": "west",
                "text": "Cats can rotate each ear independently.",
                "status": {"verified": true, "sentCount": 128},
                "createdAt": "2022-06-29T04:15:00 -0500"
            }
        ]
        """#

        let facts = try await decodeResponse(response)
        let expectedDate = try makeUTCDate(year: 2022, month: 6, day: 29, hour: 9, minute: 15)

        XCTAssertEqual(facts.map(\.id), ["utc", "east", "west"])
        XCTAssertEqual(facts.map(\.createdAt), Array(repeating: expectedDate, count: 3))
    }

    func testIgnoresAdditionalResponseFields() async throws {
        let response = #"""
        [{
            "_id": "66ac00000000000000000002",
            "text": "A group of adult cats is commonly called a clowder.",
            "status": {
                "verified": false,
                "sentCount": 94,
                "review": {"source": "editor", "version": 2}
            },
            "createdAt": "2022-06-29T09:15:00 +0000",
            "tags": ["cats", "behaviour"],
            "metadata": {"language": "en"}
        }]
        """#

        let facts = try await decodeResponse(response)

        XCTAssertEqual(facts, try [
            CatFact(
                id: "66ac00000000000000000002",
                text: "A group of adult cats is commonly called a clowder.",
                createdAt: makeUTCDate(year: 2022, month: 6, day: 29, hour: 9, minute: 15),
                isVerified: false
            )
        ])
    }

    func testPreservesUnicodeAndEscapedText() async throws {
        let response = #"""
        [{
            "_id": "66ac00000000000000000001",
            "text": "A cat says \"meow\".\nA cat in a caf\u00e9 \ud83d\udc08",
            "status": {"verified": true, "sentCount": 128},
            "createdAt": "2022-06-29T09:15:00 +0000"
        }]
        """#

        let facts = try await decodeResponse(response)

        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts.first?.text, "A cat says \"meow\".\nA cat in a café 🐈")
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
        let response = #"""
        [
            {"_id": "true", "text": "Cat fact", "createdAt": "2022-06-29T09:15:00 +0000", "status": {"verified": true, "sentCount": 128}},
            {"_id": "false", "text": "Cat fact", "createdAt": "2022-06-29T09:15:00 +0000", "status": {"verified": false, "sentCount": 94}},
            {"_id": "null", "text": "Cat fact", "createdAt": "2022-06-29T09:15:00 +0000", "status": {"verified": null}},
            {"_id": "missing", "text": "Cat fact", "createdAt": "2022-06-29T09:15:00 +0000", "status": {}}
        ]
        """#

        let facts = try await decodeResponse(response)

        XCTAssertEqual(facts.map(\.isVerified), [true, false, false, false])
    }

    func testRejectsInvalidRequiredFieldsInsteadOfDroppingRecords() async throws {
        let cases: [(name: String, record: String, field: String)] = [
            ("missing id", #"{"text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":true}}"#, "_id"),
            ("null id", #"{"_id":null,"text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":true}}"#, "_id"),
            ("numeric id", #"{"_id":123,"text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":true}}"#, "_id"),
            ("missing text", #"{"_id":"fact-2","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":true}}"#, "text"),
            ("null text", #"{"_id":"fact-2","text":null,"createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":true}}"#, "text"),
            ("numeric text", #"{"_id":"fact-2","text":123,"createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":true}}"#, "text"),
            ("missing date", #"{"_id":"fact-2","text":"Cat fact","status":{"verified":true}}"#, "createdAt"),
            ("null date", #"{"_id":"fact-2","text":"Cat fact","createdAt":null,"status":{"verified":true}}"#, "createdAt"),
            ("numeric date", #"{"_id":"fact-2","text":"Cat fact","createdAt":1656494100,"status":{"verified":true}}"#, "createdAt"),
            ("invalid date", #"{"_id":"fact-2","text":"Cat fact","createdAt":"not-a-date","status":{"verified":true}}"#, "createdAt"),
            ("missing status", #"{"_id":"fact-2","text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000"}"#, "status"),
            ("null status", #"{"_id":"fact-2","text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":null}"#, "status"),
            ("array status", #"{"_id":"fact-2","text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":[]}"#, "status"),
            ("string verified", #"{"_id":"fact-2","text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":"true"}}"#, "verified"),
            ("numeric verified", #"{"_id":"fact-2","text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":1}}"#, "verified"),
            ("object verified", #"{"_id":"fact-2","text":"Cat fact","createdAt":"2022-06-29T09:15:00 +0000","status":{"verified":{}}}"#, "verified")
        ]

        for testCase in cases {
            do {
                _ = try await decodeResponse("[\(validFactJSON),\(testCase.record)]")
                XCTFail("Expected the entire response to fail: \(testCase.name)")
            } catch FactsServiceError.decoding(let error) {
                let path: [any CodingKey]
                switch error {
                case .keyNotFound(let key, let context):
                    path = context.codingPath + [key]
                case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
                    path = context.codingPath
                @unknown default:
                    XCTFail("Unexpected decoding error: \(error)")
                    continue
                }
                XCTAssertEqual(path.first?.intValue, 1, testCase.name)
                XCTAssertEqual(path.last?.stringValue, testCase.field, testCase.name)
            } catch {
                XCTFail("Unexpected error for \(testCase.name): \(error)")
            }
        }
    }

    func testRejectsEmptyBodyMalformedJSONAndNonArrayResponse() async {
        for body in ["", "not JSON", "[", "{}", "null", "42", #""Cat fact""#, "[null]", "[42]", #"["Cat fact"]"#] {
            do {
                _ = try await decodeResponse(body)
                XCTFail("Expected a decoding error for body: \(body.debugDescription)")
            } catch FactsServiceError.decoding(let error) {
                print("Expected decoding error for body \(body.debugDescription): \(error)")
            } catch {
                XCTFail("Unexpected error for body \(body.debugDescription): \(error)")
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
        } catch let error as FactsServiceError {
            switch error {
            case .invalidBaseURL:
                print("Expected base URL error: \(error)")
            default:
                XCTFail("Unexpected error: \(error)")
            }
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
        } catch let error as CancellationError {
            print("Expected cancellation error: \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let requests = await client.requests
        XCTAssertTrue(requests.isEmpty)
    }

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return try XCTUnwrap(calendar.date(from: components))
    }

    private func decodeResponse(_ response: String) async throws -> [CatFact] {
        let client = HTTPClientStub(result: .success(Data(response.utf8)))
        return try await FactsService(httpClient: client, baseURL: baseURL).fetchFacts()
    }

    private let validFactJSON = #"""
    {
        "_id": "66ac00000000000000000001",
        "text": "Cats can rotate each ear independently and direct it toward a sound without moving their head. This ability helps them pinpoint quiet rustling and other subtle noises with impressive accuracy.",
        "status": {"verified": true, "sentCount": 128},
        "createdAt": "2022-06-29T09:15:00 +0000"
    }
    """#
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
