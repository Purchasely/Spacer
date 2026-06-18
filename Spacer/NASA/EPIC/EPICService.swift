//
//  EPICService.swift
//  Spacer
//

import Foundation

protocol EPICServicing: Sendable {
    func latest() async throws -> [EPICImage]
}

nonisolated struct EPICService: EPICServicing {
    let client: APIClient

    func latest() async throws -> [EPICImage] {
        try await client.get(EPICEndpoint.natural())
    }
}
