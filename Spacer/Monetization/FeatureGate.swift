//
//  FeatureGate.swift
//  Spacer
//
//  Typed gates + the single gated-action path. Every gate maps 1:1 to a Purchasely
//  placement. `GatedAction` makes the resume-on-purchase / revert-on-cancel contract
//  type-enforced: deferred actions give a no-op rollback; state-selecting actions
//  give a real rollback. All gating flows through one `attempt(_:action:)` method,
//  so Phase 2 swaps the no-op presenter for the real Purchasely paywall with no
//  call-site changes.
//

import Foundation

enum FeatureGate: String, CaseIterable, Sendable {
    case favoriteOverCap
    case apodArchive
    case hdDownload
    case exploreDepth
    case dailyNotif

    /// Purchasely placement id this gate presents.
    var placement: String {
        switch self {
        case .favoriteOverCap: "favorites"
        case .apodArchive: "apod_archive"
        case .hdDownload: "hd"
        case .exploreDepth: "explore"
        case .dailyNotif: "notifications"
        }
    }
}

/// A deferred action guarded by a gate. `perform` runs on unlock; `rollback` runs
/// on cancellation (defaults to a no-op for purely additive actions).
@MainActor
struct GatedAction {
    let perform: () -> Void
    let rollback: () -> Void

    init(perform: @escaping () -> Void, rollback: @escaping () -> Void = {}) {
        self.perform = perform
        self.rollback = rollback
    }
}

/// Presents a paywall for a gate, returning whether access was granted.
@MainActor
protocol PaywallPresenting {
    func present(_ gate: FeatureGate) async -> Bool
}

/// Phase 1 presenter: no paywall UI yet, so a gated tap simply does not unlock.
/// Phase 2 replaces this with the Purchasely-backed presenter.
@MainActor
struct NoOpPaywallPresenter: PaywallPresenting {
    func present(_ gate: FeatureGate) async -> Bool { false }
}

/// The one code path every gate flows through.
@MainActor
@Observable
final class FeatureGateCoordinator {
    private let entitlements: EntitlementProvider
    var presenter: PaywallPresenting

    init(entitlements: EntitlementProvider, presenter: PaywallPresenting = NoOpPaywallPresenter()) {
        self.entitlements = entitlements
        self.presenter = presenter
    }

    /// Attempts a gated action: performs immediately if unlocked, otherwise presents
    /// the paywall and performs on unlock / rolls back on cancel.
    func attempt(_ gate: FeatureGate, action: GatedAction) async {
        if entitlements.isUnlocked(gate) {
            action.perform()
            return
        }
        _ = await presenter.present(gate)
        // Re-check after the paywall closes instead of trusting the presenter's result:
        // in Observer mode the app runs the purchase, so the SDK's dismissal outcome
        // doesn't report it — the synced entitlement (via synchronize) is the truth.
        await entitlements.refresh()
        if entitlements.isUnlocked(gate) {
            action.perform()
        } else {
            action.rollback()
        }
    }
}
