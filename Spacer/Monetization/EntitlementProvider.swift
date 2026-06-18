//
//  EntitlementProvider.swift
//  Spacer
//
//  The single source of truth for gating. The whole UI reads capabilities from
//  here — never from Purchasely or StoreKit directly. In Phase 1 this is a stub
//  pinned to `.free`; Phase 2 wires the real state machine + Purchasely behind
//  the SAME capability API, so no content code changes.
//

import Foundation

@MainActor
@Observable
final class EntitlementProvider {
    enum Status: Equatable, Sendable {
        case free
        case premiumActive
        /// Apple billing-retry — premium stays UNLOCKED.
        case grace
        case expired
    }

    private(set) var status: Status

    init(status: Status = .free) {
        self.status = status
    }

    /// Pulls the validated subscription state from Purchasely (via the wrapper —
    /// this stays the single source of truth and never imports the SDK directly)
    /// and updates `status`. Returns the determined active flag, or `nil` when the
    /// state couldn't be determined (in which case `status` is left as-is rather
    /// than downgrading a premium user).
    @discardableResult
    func refresh() async -> Bool? {
        let active = await PurchaselyService.hasActiveSubscription()
        if let active { status = active ? .premiumActive : .free }
        return active
    }

    /// True while the user has premium access (active or in grace).
    var isPremium: Bool {
        switch status {
        case .premiumActive, .grace: true
        case .free, .expired: false
        }
    }

    /// Whether a gated feature is currently unlocked. Grace-keeps-premium and the
    /// re-lock rules live ONLY here — UI never branches on raw `status`.
    func isUnlocked(_ feature: FeatureGate) -> Bool {
        isPremium
    }

    /// Maximum favourites allowed. `nil` means unlimited (premium); `0` means
    /// favouriting is entirely a premium feature for free users.
    var favoriteCap: Int? {
        isPremium ? nil : 0
    }

    /// Number of past days of APOD archive a free user may browse (inclusive of today).
    var apodFreeWindowDays: Int { 7 }
}
