//
//  AppFont.swift
//  Spacer
//
//  Type voice: a serif display face for hero/editorial copy, SF Pro for UI/body,
//  and SF Mono for "instrument" data (velocity, miss-distance, sol, coordinates).
//  We use the system serif (New York) and system monospaced rather than bundling
//  Fraunces, to keep the app dependency-free; all faces scale with Dynamic Type
//  because they are built from `Font.system(_:design:)` text styles.
//

import SwiftUI

enum AppFont {
    /// Large editorial hero title — system serif.
    static let hero = Font.system(.largeTitle, design: .serif).weight(.semibold)
    /// Section / screen title — system serif.
    static let title = Font.system(.title2, design: .serif).weight(.semibold)
    /// Card / row heading.
    static let heading = Font.system(.headline)
    /// Body copy (APOD explanation, descriptions) — serif reads as editorial.
    static let body = Font.system(.body, design: .serif)
    /// Standard UI body.
    static let ui = Font.system(.body)
    /// Captions, metadata.
    static let caption = Font.system(.caption)
    /// Instrument readouts — monospaced, tabular figures.
    static let mono = Font.system(.footnote, design: .monospaced)
    /// Larger monospaced data emphasis.
    static let monoEmphasis = Font.system(.callout, design: .monospaced).weight(.medium)
}
