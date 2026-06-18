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
                        // onDismissed MUST always fire. A missing "onDismissed" line for a
                        // paywall you opened is the user-switch-dismiss-callback freeze
                        // (the continuation below never resumes → the action chain hangs).
                        Self.logOutcome(outcome, placement: placementId)
                        let granted = outcome.purchaseResult == .purchased
                            || outcome.purchaseResult == .restored
                        box.resume(granted)
                    }
                }
                .build()
                .preload { presentation, error in
                    Task { @MainActor [weak self] in
                        guard let presentation else {
                            // Pre-display error: error != nil and there is NO closeReason —
                            // onDismissed does NOT fire here (error / closeReason are mutually
                            // exclusive). This is the "erreur pré-affichage" case.
                            print("[Spacer] Paywall '\(placementId)' preload FAILED — error: \(error?.localizedDescription ?? "unknown"), closeReason: n/a (pre-display); onDismissed will NOT fire")
                            box.resume(false)
                            return
                        }
                        print("[Spacer] Paywall '\(placementId)' loaded — type: \(Self.describe(presentation.type)), isFlow: \(presentation.isFlow)")
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

    // MARK: - Outcome diagnostics

    /// Logs every dismissal-outcome field and the canonical test case it matches, so the
    /// console proves which path fired. Reference matrix:
    ///  • Purchase          → purchaseResult PURCHASED, plan != nil, closeReason PROGRAMMATIC
    ///  • Close (X) button   → closeReason BUTTON, purchaseResult NONE
    ///  • System back / swipe → closeReason INTERACTIVE_DISMISS, purchaseResult NONE
    ///  • Restore            → purchaseResult RESTORED, plan != nil
    ///  • Pre-display error   → logged in preload (error != nil, no closeReason; onDismissed not called)
    private static func logOutcome(_ outcome: PLYPresentationOutcome, placement: String) {
        let plan = outcome.plan
        print("[Spacer] onDismissed '\(placement)' — purchaseResult: \(describe(outcome.purchaseResult)), "
            + "plan: \(plan?.vendorId ?? "nil") [\(plan?.appleProductId ?? "nil")], "
            + "closeReason: \(describe(outcome.closeReason)), "
            + "error: \(outcome.error?.localizedDescription ?? "nil")")
        print("[Spacer] → case: \(classify(outcome))")
    }

    private static func classify(_ o: PLYPresentationOutcome) -> String {
        switch o.purchaseResult {
        case .purchased: return "PURCHASE (expect plan != nil + closeReason PROGRAMMATIC)"
        case .restored:  return "RESTORE (expect plan != nil)"
        case .cancelled: return "purchase CANCELLED"
        case .none:
            switch o.closeReason {
            case .button:             return "CLOSE via X button"
            case .interactiveDismiss: return "SYSTEM BACK / swipe-to-dismiss"
            case .programmatic:       return "programmatic close (no purchase)"
            case .none:               return "dismissed — no purchase, no reason"
            @unknown default:         return "unknown closeReason"
            }
        @unknown default: return "unknown purchaseResult"
        }
    }

    private static func describe(_ r: PLYPurchaseResult) -> String {
        switch r {
        case .purchased: "PURCHASED"
        case .restored:  "RESTORED"
        case .cancelled: "CANCELLED"
        case .none:      "NONE"
        @unknown default: "unknown"
        }
    }

    private static func describe(_ r: PLYCloseReason) -> String {
        switch r {
        case .button:             "BUTTON"
        case .interactiveDismiss: "INTERACTIVE_DISMISS"
        case .programmatic:       "PROGRAMMATIC"
        case .none:               "NONE"
        @unknown default:         "unknown"
        }
    }

    private static func describe(_ t: PLYPresentationType) -> String {
        switch t {
        case .normal:      "NORMAL"
        case .fallback:    "FALLBACK"
        case .deactivated: "DEACTIVATED"
        case .client:      "CLIENT"
        @unknown default:  "unknown"
        }
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
