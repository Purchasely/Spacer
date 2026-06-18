//
//  EPICImage.swift
//  Spacer
//
//  EPIC full-disk Earth imagery. The `image` field has NO extension; the archive
//  URL is built from the timestamp:
//    https://epic.gsfc.nasa.gov/archive/natural/YYYY/MM/DD/png/{image}.png
//  The archive host is NOT metered, so we build image URLs WITHOUT api_key.
//  Imagery lags 1–2 days; we pick a representative image per day for the grid.
//

import Foundation

nonisolated struct EPICImage: Codable, Sendable, Identifiable, Equatable {
    let identifier: String
    let caption: String
    let image: String
    let date: String

    var id: String { identifier }

    private static let archiveHost = "https://epic.gsfc.nasa.gov/archive/natural"

    /// Parses the "yyyy-MM-dd HH:mm:ss" timestamp into Y/M/D path components.
    private var pathComponents: (year: String, month: String, day: String)? {
        let datePart = date.split(separator: " ").first.map(String.init) ?? date
        let pieces = datePart.split(separator: "-")
        guard pieces.count == 3 else { return nil }
        return (String(pieces[0]), String(pieces[1]), String(pieces[2]))
    }

    /// Full-resolution PNG (no api_key — unmetered archive host).
    var imageURL: URL? {
        guard let p = pathComponents else { return nil }
        return URL(string: "\(Self.archiveHost)/\(p.year)/\(p.month)/\(p.day)/png/\(image).png")
    }

    /// Smaller JPEG thumbnail for grids.
    var thumbnailURL: URL? {
        guard let p = pathComponents else { return nil }
        return URL(string: "\(Self.archiveHost)/\(p.year)/\(p.month)/\(p.day)/thumbs/\(image).jpg")
    }

    var displayDate: String {
        date.split(separator: " ").first.map(String.init) ?? date
    }
}
