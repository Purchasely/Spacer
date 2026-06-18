//
//  TodayViewModel.swift
//  Spacer
//
//  Loads today's APOD with serve-stale-then-revalidate: a successful fetch is
//  cached to disk; on offline/429 we fall back silently to the cached copy.
//

import Foundation

@MainActor
@Observable
final class TodayViewModel {
    enum Phase {
        case loading
        case loaded(APOD)
        case failed(APIError)
    }

    private(set) var phase: Phase = .loading

    private let service: any APODServicing
    private let cacheKey = "apod-today"

    init(service: any APODServicing) {
        self.service = service
    }

    /// Loads today's APOD. Idempotent: once loaded it won't re-fetch on a tab
    /// reappear unless `force` is set (pull-to-refresh).
    func load(force: Bool = false) async {
        if case .loaded = phase, !force { return }
        phase = .loading
        do {
            let apod = try await service.today()
            await JSONDiskCache.shared.save(apod, forKey: cacheKey)
            phase = .loaded(apod)
        } catch let error as APIError {
            if error.shouldServeCache,
               let cached = await JSONDiskCache.shared.load(APOD.self, forKey: cacheKey) {
                phase = .loaded(cached)
            } else {
                phase = .failed(error)
            }
        } catch {
            phase = .failed(.invalidResponse)
        }
    }
}
