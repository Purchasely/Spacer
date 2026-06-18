//
//  Spacing.swift
//  Spacer
//
//  Layout tokens: an 8pt-based spacing scale and a corner-radius scale.
//

import CoreGraphics

enum Spacing {
    /// 4pt
    static let xxs: CGFloat = 4
    /// 8pt
    static let xs: CGFloat = 8
    /// 12pt
    static let sm: CGFloat = 12
    /// 16pt — default content inset.
    static let md: CGFloat = 16
    /// 24pt
    static let lg: CGFloat = 24
    /// 32pt
    static let xl: CGFloat = 32
    /// 48pt
    static let xxl: CGFloat = 48
}

enum Radius {
    /// Cards.
    static let card: CGFloat = 20
    /// Sheets / paywall surfaces.
    static let sheet: CGFloat = 28
    /// Buttons / controls.
    static let control: CGFloat = 12
    /// Fully rounded pills.
    static let pill: CGFloat = 999
}
