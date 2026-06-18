//
//  EPICEndpoint.swift
//  Spacer
//

import Foundation

nonisolated enum EPICEndpoint {
    /// Most recent natural-color collection (metadata only — goes through api.nasa.gov).
    static func natural() -> Endpoint {
        Endpoint(path: "/EPIC/api/natural")
    }

    /// Natural-color collection for a specific date.
    static func natural(on date: Date) -> Endpoint {
        Endpoint(path: "/EPIC/api/natural/date/\(NASADate.string(from: date))")
    }
}
