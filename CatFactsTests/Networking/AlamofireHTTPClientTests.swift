import XCTest
import Alamofire
@testable import CatFacts

final class AlamofireHTTPClientTests: XCTestCase {
    func testReturnsSuccessfulResponseBody() async throws {
        let scenario = HTTPStubScenario.success
        let expectedResponse = try scenario.response.get()

        let data = try await makeClient().send(request(for: scenario))

        XCTAssertEqual(data, expectedResponse.body)
    }

    func testAcceptsAnEmptySuccessfulBody() async throws {
        let data = try await makeClient().send(request(for: .empty))

        XCTAssertTrue(data.isEmpty)
    }

    func testMapsHTTPStatusError() async throws {
        let request = try request(for: .serverError)

        await assertThrowsError("Expected an HTTP error") {
            try await makeClient().send(request)
        } verify: { error in
            XCTAssertEqual(error as? HTTPClientError, .httpStatus(503))
        }
    }

    func testPreservesTransportErrorCode() async throws {
        let request = try request(for: .offline)

        await assertThrowsError("Expected a transport error") {
            try await makeClient().send(request)
        } verify: { error in
            XCTAssertEqual(error as? HTTPClientError, .transport(.notConnectedToInternet))
        }
    }

    func testReportsCancellationSeparatelyFromNetworkErrors() async throws {
        let request = try request(for: .cancelled)

        await assertThrowsError("Expected cancellation") {
            try await makeClient().send(request)
        } verify: { error in
            XCTAssertTrue(error is CancellationError, "Unexpected error: \(error)")
        }
    }

    private func makeClient() -> AlamofireHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTPResponseStub.self]
        configuration.urlCache = nil
        return AlamofireHTTPClient(session: Session(configuration: configuration))
    }

    private func request(for scenario: HTTPStubScenario) throws -> URLRequest {
        let url = try XCTUnwrap(URL(string: "https://catfacts.test\(scenario.rawValue)"))
        return URLRequest(url: url)
    }
}

private enum HTTPStubScenario: String {
    case success = "/success"
    case empty = "/empty"
    case serverError = "/server-error"
    case offline = "/offline"
    case cancelled = "/cancelled"

    var response: Result<(statusCode: Int, body: Data), URLError> {
        switch self {
        case .success:
            return .success((statusCode: 200, body: Data("[]".utf8)))
        case .empty:
            return .success((statusCode: 200, body: Data()))
        case .serverError:
            return .success((statusCode: 503, body: Data("[]".utf8)))
        case .offline:
            return .failure(URLError(.notConnectedToInternet))
        case .cancelled:
            return .failure(URLError(.cancelled))
        }
    }
}

private final class HTTPResponseStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "catfacts.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let scenario = HTTPStubScenario(rawValue: url.path) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let stubResponse: (statusCode: Int, body: Data)
        do {
            stubResponse = try scenario.response.get()
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let response = HTTPURLResponse(url: url, statusCode: stubResponse.statusCode, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !stubResponse.body.isEmpty {
            client?.urlProtocol(self, didLoad: stubResponse.body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
