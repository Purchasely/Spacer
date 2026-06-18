//
//  FavoriteItem.swift
//  Spacer
//
//  The only SwiftData @Model. Favourites are heterogeneous (APOD / EPIC),
//  distinguished by `contentType`. `dedupKey` ("type#sourceID") is the unique key,
//  shipped in V1 so we never face a dangerous add-unique-later migration. URLs are
//  stored WITHOUT api_key (image hosts don't meter), so a key rotation never
//  invalidates saved favourites.
//

import Foundation
import SwiftData

enum FavoriteContentType: String, Codable, Sendable, CaseIterable {
    case apod
    case epic
}

@Model
final class FavoriteItem {
    /// "contentType#sourceID" — unique. Per-type sourceID: APOD=date, EPIC=image name.
    @Attribute(.unique) var dedupKey: String
    var contentTypeRaw: String
    var sourceID: String
    var title: String
    var thumbnailURLString: String?
    var fullURLString: String?
    var isVideo: Bool
    var dateAdded: Date

    init(contentType: FavoriteContentType,
         sourceID: String,
         title: String,
         thumbnailURL: URL? = nil,
         fullURL: URL? = nil,
         isVideo: Bool = false,
         dateAdded: Date = Date()) {
        self.contentTypeRaw = contentType.rawValue
        self.sourceID = sourceID
        self.dedupKey = "\(contentType.rawValue)#\(sourceID)"
        self.title = title
        self.thumbnailURLString = thumbnailURL?.absoluteString
        self.fullURLString = fullURL?.absoluteString
        self.isVideo = isVideo
        self.dateAdded = dateAdded
    }

    var contentType: FavoriteContentType {
        FavoriteContentType(rawValue: contentTypeRaw) ?? .apod
    }

    var thumbnailURL: URL? { thumbnailURLString.flatMap(URL.init(string:)) }
    var fullURL: URL? { fullURLString.flatMap(URL.init(string:)) }

    static func dedupKey(_ contentType: FavoriteContentType, _ sourceID: String) -> String {
        "\(contentType.rawValue)#\(sourceID)"
    }
}
