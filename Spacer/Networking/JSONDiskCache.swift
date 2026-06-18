//
//  JSONDiskCache.swift
//  Spacer
//
//  Tiny on-disk cache for decoded NASA JSON, used for the "last-viewed content"
//  offline fallback and per-date immutability (APOD for a past date never changes,
//  so it's fetched at most once). Keyed by caller-supplied strings.
//

import Foundation

actor JSONDiskCache {
    static let shared = JSONDiskCache()

    private let directory: URL
    private let fileManager = FileManager.default

    init(name: String = "JSONCache") {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = caches.appendingPathComponent(name, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save<T: Encodable & Sendable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func load<T: Decodable & Sendable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func fileURL(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return directory.appendingPathComponent(safe).appendingPathExtension("json")
    }
}
