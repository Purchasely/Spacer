# Spacer

An iOS app for exploring NASA imagery — the Astronomy Picture of the Day (APOD)
and a recent picture feed — with a premium tier monetized through **Purchasely**.

- **Platform:** iOS 17+, iPhone-only, SwiftUI, dark-mode-first
- **Language:** Swift 6 (strict concurrency, default actor isolation = MainActor)
- **Data:** NASA Open APIs (APOD) + SwiftData for favorites
- **Monetization:** Purchasely iOS SDK `6.0.0-rc.1` (Full mode, StoreKit 2)

## Features

- **Today** — the Astronomy Picture of the Day, with a full-screen, pinch-to-zoom
  viewer that progressively upgrades a cached preview to HD (no spinner).
- **Explore** — a recent APOD feed, cached on disk and refreshed at most once per
  day; degrades gracefully to cache when offline or rate-limited.
- **Favorites** — save images (SwiftData), browse offline. Premium-gated.
- **Profile** — subscription status, Restore Purchases, and a daily-reminder
  local notification.

## Purchasely integration

The SDK is isolated behind a small wrapper layer in `Spacer/Monetization/` so the
rest of the app never imports Purchasely directly.

| Concern | Where | Notes |
|---------|-------|-------|
| SDK lifecycle | `PurchaselyService` | `start()` in Full mode + StoreKit 2; `restorePurchases()`; `userSubscriptions` / `synchronize` helpers |
| Paywall display | `PurchaselyPaywallPresenter` | v6 `PLYPresentationBuilder` → `preload` → type-guarded `display`; handles `normal`/`fallback`/`deactivated`/`client` |
| Entitlement state | `EntitlementProvider` | Single source of truth for gating; synced from validated subscription state |
| Gating | `FeatureGateCoordinator` / `FeatureGate` | Every gated tap flows through `attempt(_:action:)` |

**Running mode:** Full — Purchasely owns and validates the purchase flow.

**Entitlement sync** refreshes from `Purchasely.userSubscriptions` on launch, on
foreground (after `synchronize()`), after a paywall purchase, and after a restore.
A failed/unknown check never downgrades a subscriber.

**Onboarding paywall:** on launch, if the subscription check definitively returns
no active subscription, the app presents the `"onboarding"` placement. Gated
features present the `"premium"` placement.

**Restore Purchases** lives in Profile (App Store Guideline 3.1.1).

## Setup

Requires Xcode 16+ and the Purchasely SDK (resolved automatically via Swift
Package Manager from the pinned `6.0.0-rc.1`).

1. Clone the repo.
2. Copy the secrets template and fill in your keys:
   ```bash
   cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
   ```
   - `NASA_API_KEY` — a free key from <https://api.nasa.gov> (defaults to the
     rate-limited `DEMO_KEY` if absent).
   - `PURCHASELY_API_KEY` — from the Purchasely Console → App Settings.
3. Open `Spacer.xcodeproj`, let SPM resolve `Purchasely-iOS`, build, and run.

> `Config/Secrets.xcconfig` is gitignored — never commit real keys.

## Project layout

```
Spacer/
  App/            App entry point, DI root (AppModel), root tab view
  NASA/           APOD service + Today / Explore views and view models
  Monetization/   Purchasely wrapper, entitlements, feature gates
  Notifications/  Local daily-reminder notification
  ImageCache/     Two-tier (memory + disk) downsampling image loader
  Favorites/      SwiftData-backed favorites
  Networking/     Async APIClient, rate limiter, JSON disk cache
  DesignSystem/   Colors, fonts, spacing, reusable components
```
