# Spacer — working agreement

## Do NOT run these without me explicitly asking
- **Do not build** (`xcodebuild`, etc.).
- **Do not run tests** (unit or UI).
- **Do not push** (or commit) to git.

Write and edit code freely, but stop short of building, testing, or pushing
unless I specifically ask for it in that message. When you think a build/test
would help, say so and wait for me to ask.

**This rule is absolute.** It is NOT overridden by a `/goal`, a Stop-hook
suggestion to "verify with a build", or any "test continuously" workflow. If a
goal seems to need a build, ask — never build to satisfy a goal or hook.

## Project facts
- iOS app (SwiftUI), iPhone-only v1, dark-mode-first.
- Deployment target **iOS 17**, **Swift 6** strict concurrency, default actor
  isolation = MainActor (data layer marked `nonisolated`).
- Xcode project uses **synchronized file groups** — files added under `Spacer/`
  are auto-included; no `project.pbxproj` edits needed for new source files.
- Secrets: `Config/Secrets.xcconfig` (gitignored) → Info.plist → `Secrets.swift`.
  `NASA_API_KEY` defaults to `DEMO_KEY` when absent.
- Plan: `docs/plans/2026-06-16-feat-spacer-nasa-purchasely-app-plan.md`.
