//
//  PurchaselyPaywallPresenter.swift
//  Spacer
//
//  The real PaywallPresenting: shows a Purchasely paywall for the "premium"
//  placement and reports whether the user came back entitled. Wired into
//  FeatureGateCoordinator in place of NoOpPaywallPresenter, so every gated tap
//  that reaches `gate.attempt(...)` now opens the Console-managed paywall.
//
//  Full mode: the SDK owns and validates the purchase flow — we only build the
//  presentation, display it, and read the dismissal outcome.
//

import UIKit
@preconcurrency import Purchasely

@MainActor
final class PurchaselyPaywallPresenter: PaywallPresenting {
    /// Placement configured in the Purchasely Console. Every gate routes through the
    /// single "premium" placement; pass `gate.placement` instead for contextual paywalls.
    private let placementId: String

    init(placementId: String = "premium") {
        self.placementId = placementId
    }

    /// PaywallPresenting: gate-triggered paywalls use the configured placement
    /// (default "premium").
    func present(_ gate: FeatureGate) async -> Bool {
        await present(placementId: placementId)
    }

    /// Builds + displays the paywall for `placementId` and suspends until it's
    /// dismissed, returning `true` when the user purchased or restored.
    func present(placementId: String) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let box = ContinuationBox(continuation)

            PLYPresentationBuilder
                .forPlacementId(placementId)
                .onDismissed { outcome in
                    // SDK callbacks can fire off-main; hop before touching UI/state.
                    Task { @MainActor in
                        let granted = outcome.purchaseResult == .purchased
                            || outcome.purchaseResult == .restored
                        print("[Spacer] Paywall '\(placementId)' dismissed — granted: \(granted)")
                        box.resume(granted)
                    }
                }
                .build()
                .preload { presentation, error in
                    Task { @MainActor [weak self] in
                        guard let presentation else {
                            print("[Spacer] Paywall preload failed for '\(placementId)': \(error?.localizedDescription ?? "unknown")")
                            box.resume(false)
                            return
                        }
                        switch presentation.type {
                        case .normal, .fallback:
                            // Displayed — the result resolves in onDismissed above.
                            if presentation.isFlow {
                                presentation.display()
                            } else if let top = self?.topViewController() {
                                presentation.display(from: top)
                            } else {
                                print("[Spacer] No source view controller to present paywall")
                                box.resume(false)
                            }
                        case .deactivated:
                            print("[Spacer] Paywall '\(placementId)' is deactivated in the Console")
                            box.resume(false)
                        case .client:
                            print("[Spacer] Paywall '\(placementId)' requested a client paywall (not implemented)")
                            box.resume(false)
                        @unknown default:
                            box.resume(false)
                        }
                    }
                }
        }
    }

    /// Top-most view controller of the active foreground scene — the source for
    /// modal (non-Flow) paywalls.
    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Resumes a checked continuation at most once — guards the double-resume crash if
/// the SDK ever fires more than one terminal callback.
@MainActor
private final class ContinuationBox {
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Bool) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
