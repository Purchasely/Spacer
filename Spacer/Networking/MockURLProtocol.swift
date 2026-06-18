//
//  MockURLProtocol.swift
//  Spacer
//
//  Intercepts URLSession requests for unit tests. Install via a custom
//  URLSessionConfiguration; set `requestHandler` to stub responses (status,
//  headers, body) or throw transport errors. Lives in the app target so tests
//  can drive APIClient through `@testable import Spacer`.
//

import Foundation

nonisolated final class MockURLProtocol: URLProtocol {
    /// Stub for each intercepted request. Returns a response + body, or throws.
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Builds a session configuration that routes all traffic through this protocol.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
