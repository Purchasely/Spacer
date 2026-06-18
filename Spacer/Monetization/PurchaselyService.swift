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

        // Mode is fixed for this launch (persisted; a change needs a relaunch).
        let mode = AppSettings.runningMode

        Purchasely
            .apiKey(apiKey)
            .runningMode(mode == .observer ? .observer : .full)  // v6 default is .observer
            .storekitSettings(.storeKit2)  // StoreKit 2 (iOS 15+)
            .logLevel(.debug)              // switch to .warn / .error before release
            .start { error in
                if let error {
                    print("[Spacer] Purchasely start failed: \(error.localizedDescription)")
                } else {
                    print("[Spacer] Purchasely SDK initialized (\(mode.rawValue) mode)")
                }
            }

        // In Observer mode the APP runs purchases; intercept Buy/Restore and drive
        // StoreKit. In Full mode no interceptor is needed — the SDK runs purchases.
        if mode == .observer {
            registerObserverInterceptors()
        }
    }

    /// Observer-mode interceptors: run the StoreKit flow, `synchronize()` to upload the
    /// receipt, return the result, then dismiss the paywall AFTER the interceptor
    /// resolves (calling closeAllScreens inside the closure races the SDK).
    private static func registerObserverInterceptors() {
        Purchasely.interceptAction(.purchase) { _, params in
            guard let productId = params?.plan?.appleProductId else {
                print("[Spacer] Observer purchase: plan has no Apple product id")
                return .notHandled
            }
            switch await StoreKitPurchaser.purchase(productId: productId) {
            case .purchased:
                await synchronize()
                Task { @MainActor in Purchasely.closeAllScreens() }
                return .success
            case .cancelledOrPending:
                return .notHandled   // keep the paywall up so the user can retry
            case .failed:
                return .failed
            }
        }

        Purchasely.interceptAction(.restore) { _, _ in
            let restored = await StoreKitPurchaser.restore()
            await synchronize()
            Task { @MainActor in Purchasely.closeAllScreens() }
            return restored ? .success : .failed
        }
    }

    /// Restores the user's previous purchases (e.g. after a reinstall or on a new
    /// device). In Full mode the SDK validates restored transactions itself.
    /// Returns `true` when the restore completed without error.
    static func restorePurchases() async -> Bool {
        // restoreAllProducts is a Full-mode API (the SDK does the billing). In Observer
        // mode the SDK isn't doing billing, so restore via StoreKit, then synchronize.
        switch AppSettings.runningMode {
        case .observer:
            let restored = await StoreKitPurchaser.restore()
            await synchronize()
            return restored
        case .full:
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
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
