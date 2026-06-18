//
//  APODService.swift
//  Spacer
//
//  Pure network access for APOD. Caching / offline fallback is handled by the
//  view models via JSONDiskCache so the service stays thin and testable.
//

import Foundation

protocol APODServicing: Sendable {
    func today() async throws -> APOD
    func range(from start: Date, to end: Date) async throws -> [APOD]
}

nonisolated struct APODService: APODServicing {
    let client: APIClient

    func today() async throws -> APOD {
        try await client.get(APODEndpoint.today())
    }

    func range(from start: Date, to end: Date) async throws -> [APOD] {
        try await client.get(APODEndpoint.range(from: start, to: end))
    }
}
