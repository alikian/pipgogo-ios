import Foundation
import Testing
@testable import pipgogo

struct APIClientTests {
    @Test func mapsUnauthorizedResponse() async {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 401, body: Data()))
        await #expect(throws: APIClientError.unauthorized) { try await client.account(accessToken: "not-a-real-token") }
    }

    @Test func surfacesBackendErrorMessage() async {
        let body = Data(#"{"error":{"code":"identity_unavailable","message":"Identity provider is unavailable"}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 503, body: body))
        await #expect(throws: APIClientError.server(status: 503, message: "Identity provider is unavailable")) {
            try await client.account(accessToken: "not-a-real-token")
        }
    }

    @Test func decodesBackendAccountTimestampWithFractionalSeconds() async throws {
        let body = Data(
            #"{"id":"account-1","kind":"account","version":1,"revision":1,"updated_at":"2026-09-25T12:34:56.123456Z","deleted":false,"data":{}}"#.utf8
        )
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 200, body: body))

        let account = try await client.account(accessToken: "not-a-real-token")

        #expect(account.id == "account-1")
        #expect(account.updatedAt.timeIntervalSince1970 > 0)
    }

    private func makeSession(status: Int, body: Data) -> URLSession {
        StubURLProtocol.response = HTTPURLResponse(url: URL(string: "https://example.invalid/v1/me")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        StubURLProtocol.body = body
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: HTTPURLResponse!
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didReceive: Self.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
