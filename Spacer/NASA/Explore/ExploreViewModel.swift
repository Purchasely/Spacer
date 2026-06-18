//
//  ExploreViewModel.swift
//  Spacer
//
//  Explore shows a recent APOD feed. The feed is cached to disk and refreshed at
//  most once per NASA day: a same-day cache is served WITHOUT a network call, so
//  the tab loads instantly across launches (and image URLs resolve straight from
//  the ImageLoader disk cache). Collections / full depth is a premium gate.
//

import Foundation

@MainActor
@Observable
final class ExploreViewModel {
    private(set) var apods: [APOD] = []
    private(set) var isLoading = false
    private(set) var loadError: APIError?

    /// Free browse depth (number of recent APOD days shown).
    var feedDepth: Int = 12

    private let apodService: any APODServicing
    private let cacheKey = "apod-feed"

    init(apodService: any APODServicing) {
        self.apodService = apodService
    }

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        await loadAPODFeed()
    }

    /// On-disk feed cache: tags the feed with the NASA day it was fetched so the
    /// network is hit at most once per day. `nonisolated` so its Codable conformance
    /// isn't MainActor-isolated (the project defaults to MainActor isolation), which
    /// JSONDiskCache's `Sendable & Codable` requirement needs.
    private nonisolated struct CachedFeed: Codable, Sendable {
        let fetchedOn: String
        let apods: [APOD]
    }

    private func loadAPODFeed() async {
        let today = NASADate.string(from: NASADate.today)

        // Fetched already today — serve the cache and skip the network entirely.
        if let cached = await JSONDiskCache.shared.load(CachedFeed.self, forKey: cacheKey),
           cached.fetchedOn == today, !cached.apods.isEmpty {
            apods = cached.apods
            return
        }

        let end = NASADate.today
        let start = NASADate.date(daysAgo: feedDepth - 1, from: end)
        do {
            let feed = try await apodService.range(from: start, to: end)
            // NASA returns ascending; show newest first.
            apods = feed.reversed()
            await JSONDiskCache.shared.save(CachedFeed(fetchedOn: today, apods: apods), forKey: cacheKey)
        } catch {
            if Task.isCancelled { return }   // benign: view went away mid-load
            // Degrade gracefully: on ANY error (rate-limit, offline, a 400 because
            // today isn't published yet, …) serve whatever feed we have cached rather
            // than a dead end. Only surface the error when there's nothing to show.
            if let cached = await cachedFeed() {
                apods = cached
            } else if apods.isEmpty {
                loadError = (error as? APIError) ?? .invalidResponse
            }
        }
    }

    /// Any cached feed, newest format first, then the legacy bare-`[APOD]` format
    /// older builds wrote under the same key (so an existing cache still rescues a
    /// rate-limited / offline launch).
    private func cachedFeed() async -> [APOD]? {
        if let wrapped = await JSONDiskCache.shared.load(CachedFeed.self, forKey: cacheKey),
           !wrapped.apods.isEmpty {
            return wrapped.apods
        }
        if let legacy = await JSONDiskCache.shared.load([APOD].self, forKey: cacheKey),
           !legacy.isEmpty {
            return legacy
        }
        return nil
    }
}
