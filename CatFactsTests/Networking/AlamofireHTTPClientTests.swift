import XCTest
import Alamofire
@testable import CatFacts

final class AlamofireHTTPClientTests: XCTestCase {
    func testReturnsSuccessfulResponseBody() async throws {
        let data = try await makeClient().send(request(path: "success"))

        XCTAssertEqual(data, Data("[]".utf8))
    }

    func testAcceptsAnEmptySuccessfulBody() async throws {
        let data = try await makeClient().send(request(path: "empty"))

        XCTAssertTrue(data.isEmpty)
    }

    func testMapsHTTPStatusError() async throws {
        let request = try request(path: "server-error")

        do {
            _ = try await makeClient().send(request)
            XCTFail("Expected an HTTP error")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .httpStatus(503))
        }
    }

    func testPreservesTransportErrorCode() async throws {
        let request = try request(path: "offline")

        do {
            _ = try await makeClient().send(request)
            XCTFail("Expected a transport error")
        } catch {
            XCTAssertEqual(error as? HTTPClientError, .transport(.notConnectedToInternet))
        }
    }

    func testReportsCancellationSeparatelyFromNetworkErrors() async throws {
        let request = try request(path: "cancelled")

        do {
            _ = try await makeClient().send(request)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> AlamofireHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTPResponseStub.self]
        configuration.urlCache = nil
        return AlamofireHTTPClient(session: Session(configuration: configuration))
    }

    private func request(path: String) throws -> URLRequest {
        let url = try XCTUnwrap(URL(string: "https://catfacts.test/\(path)"))
        return URLRequest(url: url)
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
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        switch url.path {
        case "/offline":
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return

        case "/cancelled":
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return

        default:
            break
        }

        let statusCode = url.path == "/server-error" ? 503 : 200
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if url.path != "/empty" {
            client?.urlProtocol(self, didLoad: Data("[]".utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
