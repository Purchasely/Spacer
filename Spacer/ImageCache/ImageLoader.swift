//
//  ImageLoader.swift
//  Spacer
//
//  Two-tier image cache: an in-memory NSCache (cost = decoded bytes) over an
//  LRU disk cache capped at 200 MB. Features:
//   • In-flight de-duplication (one network load per key, many awaiters).
//   • ImageIO downsampling to a target pixel size (caps memory on 20 MP panoramas).
//   • CPU-bound decode runs OFF the actor (Task.detached) — the actor only does
//     cache bookkeeping, so fast scrolling never stalls on the serial executor.
//   • Image bytes are fetched directly from NASA archive hosts WITHOUT api_key
//     (those hosts don't meter), so image loads never burn the metered budget.
//
//  This custom layer is deliberate (offline favourite pinning, prefetch control,
//  two-size downsampling) — URLCache can't cover those needs. See the plan's
//  "Custom ImageLoader vs AsyncImage+URLCache" resolution.
//

import UIKit
import ImageIO

/// A Sendable wrapper so a decoded image can cross the actor boundary safely.
/// UIImage here is immutable after decode.
struct SendableImage: @unchecked Sendable {
    let image: UIImage
}

actor ImageLoader {
    static let shared = ImageLoader()

    /// Standard downsample targets (points; multiplied by scale at call sites).
    enum Target {
        /// Grid thumbnail (~360 px at 3x).
        case grid
        /// Full-screen detail (~1170 px at 3x), hard-capped at 2048.
        case detail
        /// Caller-specified max pixel size.
        case custom(maxPixel: CGFloat)

        /// Final pixel size (already scaled for modern @3x displays).
        var maxPixelSize: CGFloat {
            switch self {
            case .grid: 720
            case .detail: 1536
            case .custom(let maxPixel): min(maxPixel, 2048)
            }
        }
    }

    private let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 64 * 1024 * 1024 // 64 MB
        return cache
    }()

    private let session: URLSession
    private let diskURL: URL
    private let diskCapBytes: Int = 200 * 1024 * 1024 // 200 MB
    private var inFlight: [String: Task<SendableImage, Error>] = [:]
    private let fileManager = FileManager.default

    init(session: URLSession = .shared) {
        self.session = session
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskURL = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: diskURL, withIntermediateDirectories: true)
        // Trim once at init in case we crashed mid-write previously.
        Task { await self.trimDiskIfNeeded() }
    }

    /// Returns a downsampled image for `url` at `target`. De-duplicates concurrent
    /// requests for the same key.
    func image(from url: URL, target: Target = .detail) async throws -> SendableImage {
        let maxPixel = target.maxPixelSize
        let key = Self.cacheKey(url: url, maxPixel: maxPixel)

        if let cached = memory.object(forKey: key as NSString) {
            return SendableImage(image: cached)
        }
        if let existing = inFlight[key] {
            return try await existing.value
        }

        let task = Task<SendableImage, Error> { [diskURL, session] in
            // Disk hit? Stored bytes are already downsampled, so decode is cheap.
            let fileURL = diskURL.appendingPathComponent(key)
            if let data = try? Data(contentsOf: fileURL),
               let decoded = await Self.makeImage(from: data, maxPixel: maxPixel) {
                // Warm memory here (not in the awaiter) so a cancelled awaiter — e.g.
                // a tab switch mid-load — still leaves the cache populated.
                await self.cache(decoded, forKey: key, fileURL: fileURL, write: nil)
                return decoded
            }
            // Network — image hosts are unmetered, request URL as-is (no api_key).
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.http(statusCode: http.statusCode)
            }
            guard let decoded = await Self.makeImage(from: data, maxPixel: maxPixel) else {
                throw APIError.decoding(description: "Image decode failed")
            }
            // Persist the DOWNSAMPLED bytes (small → fast disk re-hits) and warm memory.
            let downsampled = decoded.image.jpegData(compressionQuality: 0.9)
            await self.cache(decoded, forKey: key, fileURL: fileURL, write: downsampled)
            return decoded
        }

        inFlight[key] = task
        do {
            let result = try await task.value
            inFlight[key] = nil
            return result
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    /// Best-effort prefetch (ignores failures). Use for the prefetch window.
    func prefetch(_ url: URL, target: Target = .grid) {
        Task { _ = try? await image(from: url, target: target) }
    }

    /// Clears the in-memory tier (e.g. on a memory warning). Disk is untouched.
    func clearMemory() {
        memory.removeAllObjects()
    }

    /// Pins bytes for a favourited image so they survive LRU eviction by refreshing
    /// their access date. (Full copy-to-favourites dir is a Phase 1 favourites task.)
    func pin(_ url: URL, target: Target = .detail) {
        let key = Self.cacheKey(url: url, maxPixel: target.maxPixelSize)
        touch(diskURL.appendingPathComponent(key))
    }

    // MARK: - Disk

    /// Warms the memory cache and, if `write` is non-nil, persists those bytes to
    /// disk; otherwise just refreshes the file's LRU access date.
    private func cache(_ image: SendableImage, forKey key: String, fileURL: URL, write: Data?) {
        memory.setObject(image.image, forKey: key as NSString, cost: Self.cost(of: image.image))
        if let write {
            try? write.write(to: fileURL, options: .atomic)
            trimDiskIfNeeded()
        } else {
            touch(fileURL)
        }
    }

    private func touch(_ fileURL: URL) {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
    }

    private func trimDiskIfNeeded() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: diskURL, includingPropertiesForKeys: keys, options: .skipsHiddenFiles
        ) else { return }

        var entries: [(url: URL, size: Int, date: Date)] = []
        var total = 0
        for file in files {
            let values = try? file.resourceValues(forKeys: Set(keys))
            let size = values?.fileSize ?? 0
            let date = values?.contentModificationDate ?? .distantPast
            entries.append((file, size, date))
            total += size
        }
        guard total > diskCapBytes else { return }

        // Evict oldest first until under cap.
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            if total <= diskCapBytes { break }
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    // MARK: - Decode (runs off the actor)

    private static func makeImage(from data: Data, maxPixel: CGFloat) async -> SendableImage? {
        await Task.detached(priority: .utility) {
            downsample(data: data, maxPixel: maxPixel).map(SendableImage.init)
        }.value
    }

    private nonisolated static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private nonisolated static func cost(of image: UIImage) -> Int {
        let cg = image.cgImage
        let width = cg?.width ?? Int(image.size.width)
        let height = cg?.height ?? Int(image.size.height)
        return width * height * 4
    }

    private nonisolated static func cacheKey(url: URL, maxPixel: CGFloat) -> String {
        let raw = "\(url.absoluteString)#\(Int(maxPixel))"
        // STABLE hash (FNV-1a). `String.hashValue` is reseeded every process launch,
        // so it must NOT be used — it would make the disk cache miss on every cold
        // launch and re-download. FNV-1a is identical across launches.
        return stableHash(raw) + "-\(Int(maxPixel))"
    }

    private nonisolated static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3 // FNV prime
        }
        return String(hash, radix: 16)
    }
}
