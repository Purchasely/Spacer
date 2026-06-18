//
//  APODEndpoint.swift
//  Spacer
//

import Foundation

nonisolated enum APODEndpoint {
    private static let path = "/planetary/apod"

    /// Today's APOD. `thumbs=true` asks NASA for a still thumbnail for videos.
    static func today() -> Endpoint {
        Endpoint(path: path, queryItems: [URLQueryItem(name: "thumbs", value: "true")])
    }

    /// APOD range (inclusive). NASA returns an array for ranges.
    static func range(from start: Date, to end: Date) -> Endpoint {
        Endpoint(path: path, queryItems: [
            URLQueryItem(name: "start_date", value: NASADate.string(from: start)),
            URLQueryItem(name: "end_date", value: NASADate.string(from: end)),
            URLQueryItem(name: "thumbs", value: "true")
        ])
    }
}
