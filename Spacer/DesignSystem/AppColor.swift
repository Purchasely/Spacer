//
//  AppColor.swift
//  Spacer
//
//  "Observatory at night" palette — near-monochrome deep-space ink with a single
//  warm amber accent. NASA photography is the only saturated thing on screen.
//  Dark-mode-first (the app is locked to dark for v1), so tokens are defined in
//  code rather than asset Color Sets; swapping to Color Sets later is mechanical.
//

import SwiftUI

enum AppColor {
    /// #07080C — base canvas. Not pure black: avoids OLED smear and banding.
    static let bgBase = Color(hex: 0x07080C)
    /// #0E1017 — one elevation up (cards, list rows).
    static let bgRaised = Color(hex: 0x0E1017)
    /// #161922 — overlays, sheets, controls.
    static let bgOverlay = Color(hex: 0x161922)

    /// #F2F3F7 — primary text (96% white, never pure white).
    static let inkPrimary = Color(hex: 0xF2F3F7)
    /// Secondary text / captions.
    static let inkSecondary = Color(hex: 0xF2F3F7).opacity(0.66)
    /// Tertiary text / disabled.
    static let inkTertiary = Color(hex: 0xF2F3F7).opacity(0.40)

    /// #E8A24A — the single warm amber accent.
    static let accent = Color(hex: 0xE8A24A)
    /// #5FB8D4 — cool cyan, used sparingly (links, secondary signal).
    static let accentCool = Color(hex: 0x5FB8D4)
    /// #E05A4D — hazard / error states.
    static let hazard = Color(hex: 0xE05A4D)

    /// Hairline separators / 1px edge highlights.
    static let hairline = Color(hex: 0xF2F3F7).opacity(0.08)
}

extension Color {
    /// Hex initializer, e.g. `Color(hex: 0xE8A24A)`. Opaque (alpha 1).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
