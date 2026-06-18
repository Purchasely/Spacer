//
//  Secrets.swift
//  Spacer
//
//  Reads NASA_API_KEY from the Info.plist (substituted from Config/Secrets.xcconfig
//  at build time). Falls back to DEMO_KEY when absent (e.g. a fresh clone without
//  the gitignored xcconfig) so the app still builds and smoke-tests.
//

import Foundation

nonisolated enum Secrets {
    static var nasaAPIKey: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "NASA_API_KEY") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty, trimmed != "$(NASA_API_KEY)" {
            return trimmed
        }
        return "DEMO_KEY"
    }

    /// Whether we're running on the shared DEMO_KEY (tight rate limit).
    static var isUsingDemoKey: Bool { nasaAPIKey == "DEMO_KEY" }

    /// Purchasely API key, read from Info.plist (substituted from
    /// Config/Secrets.xcconfig at build time). Empty when absent — the SDK is
    /// not started in that case.
    static var purchaselyAPIKey: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "PURCHASELY_API_KEY") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty, trimmed != "$(PURCHASELY_API_KEY)" {
            return trimmed
        }
        return ""
    }
}
