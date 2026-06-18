---
date: 2026-06-16
topic: spacer
---

# Spacer — Brainstorm

## What We're Building

A premium, dark-mode-first iOS (SwiftUI) app that opens a daily "window into the
universe" using NASA's free public APIs (APOD, Mars Rover Photos, NEO/asteroids,
EPIC). Its flagship purpose is to be a realistic, beautiful showcase of the
**Purchasely** SDK — serving simultaneously as a sales/marketing demo, a clean
developer reference integration, and a shippable App Store product.

Architecture is **pure client-side**: NASA's free public API direct, Purchasely
for monetization, and on-device **local notifications** for engagement. No
backend, no server-side push, no custom alerts infrastructure.

## Why This Approach

- **Pure client over serverless/backend** — keeps the demo zero-ops and easy to
  hand to a prospect or clone as reference; every interesting behavior is
  reproducible on-device. The only features that "needed" a server (push,
  alerts) are satisfied with local notifications instead.
- **Content-first sequencing** — build the NASA browsing experiences to a polished
  bar first, then layer the Purchasely onboarding + paywalls on top. The
  entitlement matrix is defined now so content is built gate-aware from the start.
- **Hard gates** — chosen over soft metering because clean, repeatable paywall
  moments demo better and read more clearly as reference code.

## Key Decisions

- **Audience: all three equally** (demo + reference + product) → flagship quality
  everywhere; sequencing still matters even though the end-state is complete.
- **No backend.** NASA free public API + Purchasely + local notifications only.
- **Build order:** NASA content & design system first → Purchasely onboarding +
  paywalls later. Define free/premium split up front.
- **Gating: hard walls**, each limit doubling as a live-demoable paywall trigger.
- **Asteroid reminders kept as a client-side premium feature** — "remind me" on an
  upcoming close-approach schedules a local notification (a 2nd entitlement to
  showcase, no server).

### Entitlement Matrix

| Feature | Free | Premium |
|---|---|---|
| APOD (Today) | Today + last 7 days | Full archive back to 1995 |
| Favorites | 5 max | Unlimited |
| Image quality | Standard | HD view + download |
| Mars Rover | 1 rover, latest photos only | All 4 rovers, any sol/date |
| Explore feed | Browse, limited depth | Full + Collections |
| Asteroids (NEO) | Next 7 days, basic fields | Extended window + full size/orbit detail |
| Daily APOD local notification | — | ✅ on-device |
| Asteroid close-approach reminder | — | ✅ on-device local notification |

**Paywall triggers to demo:** favorite #6 · APOD older than 7 days · Mars
date-picker beyond limit · HD download · "see more" on asteroids · enabling either
notification toggle.

### Purchasely surface area to showcase

Subscription products, entitlements, onboarding paywall ("Unlock the Universe",
monthly + yearly + free trial), feature paywalls (the triggers above), promotional
offers, restore purchases, subscription management, remote paywall configuration,
audience targeting, and A/B-test readiness.

## Tech Stack

Native iOS, zero third-party dependencies except the Purchasely SDK.

| Layer | Choice |
|---|---|
| Language / UI | Swift 6 + SwiftUI |
| Min target | iOS 17 (SwiftData, `@Observable`, modern animations) |
| Architecture | MVVM + async/await |
| Concurrency | Swift Concurrency (`async/await`, actors) |
| Networking | `URLSession` + `Codable` (no library) |
| Image loading | `AsyncImage` + **custom small image cache** (in-memory `NSCache` + disk) — `AsyncImage` alone has no disk cache; the wrapper handles caching/prefetch for large NASA imagery |
| Persistence | SwiftData (favorites + preferences) |
| Monetization | Purchasely iOS SDK via SPM (the only external dep) |
| Notifications | `UserNotifications` (local only) |

**Note:** the custom image-cache layer is the one deliberate "build it ourselves"
component — contained, and a useful native-caching showcase for the reference angle.

## Open Questions

- **Entitlement persistence:** rely solely on Purchasely's entitlement state, or
  mirror it locally for offline gating of favorites/archive?
- **NASA API key:** bundle in-app (DEMO_KEY or a real key) — acceptable risk for a
  client-only showcase? Rate-limit handling/caching strategy.
- **EPIC tab:** spec lists 5 tabs (Today, Explore, Mars, Asteroids, Profile);
  EPIC Earth imagery currently lives inside Explore — confirm it isn't its own tab.
- **Offline scope:** favorites are offline per spec — does cached APOD/Mars imagery
  also need offline viewing, or just favorites?
- **Free trial mechanics:** trial length and which plan(s) carry it.
- **Tablet/iPad layout** in scope for v1, or iPhone-only first?

## Next Steps

→ `/workflows:plan` for implementation details (NASA content layer + design system
first, Purchasely integration second).
