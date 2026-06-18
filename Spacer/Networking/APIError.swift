//
//  APIError.swift
//  Spacer
//

import Foundation

/// All networking failures, surfaced with user-facing copy. `Sendable` so it can
/// cross actor boundaries back to `@MainActor` view models.
nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case offline
    /// HTTP 429. `retryAfter` is the server's `Retry-After` in seconds, if present.
    case rateLimited(retryAfter: TimeInterval?)
    /// Non-2xx, non-429 HTTP status.
    case http(statusCode: Int)
    case decoding(description: String)
    case invalidResponse
    /// Transport-level URLSession failure that isn't recognised as offline.
    case transport(description: String)

    /// Whether content should fall back to cache for this error.
    var shouldServeCache: Bool {
        switch self {
        case .offline, .rateLimited: true
        default: false
        }
    }

    /// Short, user-facing title.
    var title: String {
        switch self {
        case .offline: "You're offline"
        default: "Couldn't load"
        }
    }

    /// User-facing detail.
    var message: String {
        switch self {
        case .offline:
            "Connect to the internet to load imagery."
        default:
            "We couldn't load this right now. Please try again in a moment."
        }
    }
}
