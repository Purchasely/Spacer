//
//  AppSettings.swift
//  Spacer
//
//  Small persisted app settings. The Purchasely running mode lives here because the
//  SDK reads it ONCE at start() — it can't change after init, so a change takes
//  effect on the next launch (the Profile toggle persists it and prompts a restart).
//

import Foundation

nonisolated enum AppRunningMode: String, Sendable {
    case full
    case observer
}

nonisolated enum AppSettings {
    private static let runningModeKey = "spacer.purchasely.runningMode"

    /// Defaults to `.full` — Spacer relies on Purchasely to process and validate purchases.
    static var runningMode: AppRunningMode {
        get {
            UserDefaults.standard.string(forKey: runningModeKey)
                .flatMap(AppRunningMode.init(rawValue:)) ?? .full
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: runningModeKey) }
    }
}
