//
//  PurchaselyService.swift
//  Spacer
//
//  Owns the Purchasely SDK lifecycle. This is the single place the app talks to
//  Purchasely.* — Phase 2 will route the FeatureGate presenter and entitlement
//  sync through here, so no content/UI code ever imports the SDK directly.
//
//  Scope today: just the start. The SDK is initialised in Full mode (Purchasely
//  handles and validates the purchase flow). Paywall display, the action
//  interceptor, and user login/logout are deliberately not wired yet.
//

import Foundation
@preconcurrency import Purchasely

enum PurchaselyService {
    /// Starts the Purchasely SDK. Call once, on the main thread, as early as
    /// possible in the app lifecycle (from `AppDelegate.didFinishLaunching...`).
    ///
    /// Full mode is explicit: the v6 default is `.observer`, which would silently
    /// stop the SDK from validating purchases. Spacer wants Purchasely to own the
    /// purchase flow, so `.full` is required.
    static func start() {
        let apiKey = Secrets.purchaselyAPIKey
        guard !apiKey.isEmpty else {
            print("[Spacer] Purchasely API key missing — set PURCHASELY_API_KEY in Config/Secrets.xcconfig")
            return
        }

        Purchasely
            .apiKey(apiKey)
            .runningMode(.full)            // REQUIRED for purchase handling — v6 default is .observer
            .storekitSettings(.storeKit2)  // StoreKit 2 (iOS 15+)
            .logLevel(.debug)              // switch to .warn / .error before release
            .start { error in
                if let error {
                    print("[Spacer] Purchasely start failed: \(error.localizedDescription)")
                } else {
                    print("[Spacer] Purchasely SDK initialized")
                }
            }
    }

    /// Restores the user's previous purchases (e.g. after a reinstall or on a new
    /// device). In Full mode the SDK validates restored transactions itself.
    /// Returns `true` when the restore completed without error.
    static func restorePurchases() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            Purchasely.restoreAllProducts(
                success: {
                    print("[Spacer] Restore completed")
                    continuation.resume(returning: true)
                },
                failure: { error in
                    print("[Spacer] Restore failed: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            )
        }
    }

    /// Whether the user has an active subscription. Returns `nil` when the state
    /// couldn't be determined (network / SDK error) so callers can leave the
    /// current entitlement untouched instead of downgrading on a flaky network.
    /// Single premium tier → any active subscription grants premium.
    static func hasActiveSubscription() async -> Bool? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool?, Never>) in
            Purchasely.userSubscriptions(
                success: { subscriptions in
                    let active = (subscriptions?.isEmpty == false)
                    print("[Spacer] Entitlement check — active subscription: \(active)")
                    continuation.resume(returning: active)
                },
                failure: { _ in
                    print("[Spacer] userSubscriptions failed — keeping current entitlement")
                    continuation.resume(returning: nil)
                }
            )
        }
    }

    /// Forces a silent sync of the user's purchases with Purchasely's servers (no
    /// prompt). Call on foreground to pick up renewals / cancellations that
    /// happened in the background, then re-check entitlement.
    static func synchronize() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Purchasely.synchronize(
                success: { continuation.resume() },
                failure: { _ in continuation.resume() }
            )
        }
    }
}
