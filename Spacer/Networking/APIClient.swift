//
//  APIClient.swift
//  Spacer
//
//  Generic async JSON client over URLSession. Nonisolated so requests run off the
//  main actor. Self-throttles via a shared RateLimiter, honours `Retry-After` on
//  429, and retries transient (5xx / transport) failures with exponential backoff.
//

import Foundation

nonisolated struct APIClient: Sendable {
    let session: URLSession
    let apiKey: String
    let limiter: RateLimiter
    var maxRetries: Int

    init(session: URLSession = .shared,
         apiKey: String,
         limiter: RateLimiter = RateLimiter(),
         maxRetries: Int = 2) {
        self.session = session
        self.apiKey = apiKey
        self.limiter = limiter
        self.maxRetries = maxRetries
    }

    /// Fetches and decodes `T`. `configure` customises the decoder (e.g. a date
    /// strategy); it's `@Sendable` and the decoder never leaves this function.
    func get<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: T.Type = T.self,
        configure: (@Sendable (JSONDecoder) -> Void)? = nil
    ) async throws -> T {
        let data = try await getData(endpoint)
        let decoder = JSONDecoder()
        configure?(decoder)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(description: String(describing: error))
        }
    }

    /// Fetches raw bytes for an endpoint, applying throttling + retry policy.
    func getData(_ endpoint: Endpoint) async throws -> Data {
        let request = try endpoint.urlRequest(apiKey: apiKey)
        var lastError: APIError = .invalidResponse

        for attempt in 0...maxRetries {
            // Fail fast if we're in a 429 cooldown (throws .rateLimited).
            let delay = try await limiter.acquire()
            if delay > 0 {
                try await Task.sleep(for: .seconds(delay))
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                switch http.statusCode {
                case 200..<300:
                    return data
                case 429:
                    let retryAfter = Self.retryAfterSeconds(from: http)
                    await limiter.recordRateLimited(retryAfter: retryAfter)
                    throw APIError.rateLimited(retryAfter: retryAfter)
                case 500..<600:
                    lastError = .http(statusCode: http.statusCode)
                default:
                    throw APIError.http(statusCode: http.statusCode)
                }
            } catch let error as APIError {
                // Don't burn retries on a definitive rate-limit.
                if case .rateLimited = error { throw error }
                lastError = error
            } catch let urlError as URLError {
                if Self.isOffline(urlError) { throw APIError.offline }
                lastError = .transport(description: urlError.localizedDescription)
            }

            // Exponential backoff before the next attempt (if any remain).
            if attempt < maxRetries {
                let backoff = pow(2.0, Double(attempt)) * 0.5
                try await Task.sleep(for: .seconds(backoff))
            }
        }
        throw lastError
    }

    // MARK: - Helpers

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let seconds = TimeInterval(value) { return seconds }
        // HTTP-date form.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: value) {
            return max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    private static func isOffline(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .cannotConnectToHost, .timedOut:
            true
        default:
            false
        }
    }
}
