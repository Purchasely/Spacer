//
//  APOD.swift
//  Spacer
//
//  Astronomy Picture of the Day. Gotchas encoded here:
//   • `hdurl` and `copyright` are optional.
//   • `media_type` is "image" or "video"; a video `url` is a YouTube/Vimeo embed
//     with no `hdurl`.
//   • `date` is "yyyy-MM-dd" — decoded as String, parsed lazily via NASADate.
//

import Foundation

nonisolated struct APOD: Codable, Sendable, Identifiable, Equatable {
    let date: String
    let title: String
    let explanation: String
    let mediaType: String
    let url: URL
    let hdurl: URL?
    let copyright: String?
    let thumbnailURL: URL?

    var id: String { date }
    var isVideo: Bool { mediaType == "video" }

    /// Parsed publication date (Eastern), if the string is well-formed.
    var parsedDate: Date? { NASADate.date(from: date) }

    /// Best display URL for a still image (prefers a usable thumbnail for video).
    var displayImageURL: URL? {
        if isVideo { return thumbnailURL }
        return url
    }

    enum CodingKeys: String, CodingKey {
        case date, title, explanation, url, hdurl, copyright
        case mediaType = "media_type"
        case thumbnailURL = "thumbnail_url"
    }
}
