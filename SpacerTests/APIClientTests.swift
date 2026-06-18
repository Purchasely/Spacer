//
//  APIClientTests.swift
//  SpacerTests
//
//  Drives APIClient through MockURLProtocol. Serialized because MockURLProtocol's
//  request handler is process-global shared state.
//

import Testing
import Foundation
@testable import Spacer

/// Thread-safe counter for multi-attempt (retry) handlers.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

private func makeResponse(_ url: URL, status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
}

private let apodJSON = """
{"date":"2026-06-16","title":"Test Nebula","explanation":"A test image.",
 "media_type":"image","url":"https://apod.nasa.gov/image.jpg",
 "hdurl":"https://apod.nasa.gov/hd.jpg","copyright":"Someone"}
""".data(using: .utf8)!

@Suite(.serialized)
struct APIClientTests {
    private func makeClient() -> APIClient {
        APIClient(session: MockURLProtocol.makeSession(),
                  apiKey: "TEST",
                  limiter: RateLimiter(requestsPerMinute: 6000),
                  maxRetries: 2)
    }

    @Test func decodesSuccessfulResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(request.url!, status: 200), apodJSON)
        }
        let apod: APOD = try await makeClient().get(APODEndpoint.today())
        #expect(apod.title == "Test Nebula")
        #expect(apod.date == "2026-06-16")
        #expect(apod.isVideo == false)
        #expect(apod.hdurl != nil)
    }

    @Test func appendsAPIKeyToRequest() async throws {
        let captured = CallCounter()
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.query?.contains("api_key=TEST") == true)
            _ = captured.next()
            return (makeResponse(request.url!, status: 200), apodJSON)
        }
        _ = try await makeClient().get(APODEndpoint.today()) as APOD
        #expect(captured.count == 1)
    }

    @Test func throwsRateLimitedOn429() async {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(request.url!, status: 429, headers: ["Retry-After": "1"]), Data())
        }
        await #expect(throws: APIError.rateLimited(retryAfter: 1)) {
            _ = try await makeClient().get(APODEndpoint.today()) as APOD
        }
    }

    @Test func retriesTransientServerErrorThenSucceeds() async throws {
        let counter = CallCounter()
        MockURLProtocol.requestHandler = { request in
            let attempt = counter.next()
            if attempt == 1 {
                return (makeResponse(request.url!, status: 503), Data())
            }
            return (makeResponse(request.url!, status: 200), apodJSON)
        }
        let apod: APOD = try await makeClient().get(APODEndpoint.today())
        #expect(apod.title == "Test Nebula")
        #expect(counter.count == 2)
    }

    @Test func throwsDecodingErrorOnGarbage() async {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(request.url!, status: 200), Data("not json".utf8))
        }
        await #expect(throws: APIError.self) {
            _ = try await makeClient().get(APODEndpoint.today()) as APOD
        }
    }
}
