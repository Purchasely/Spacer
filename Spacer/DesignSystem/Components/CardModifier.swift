//
//  CardModifier.swift
//  Spacer
//
//  Dark-mode depth is built from a lightness step + a 1px top-edge inner highlight
//  (light-from-above) and a colored ambient shadow — not a heavy drop shadow.
//

import SwiftUI

struct CardModifier: ViewModifier {
    var padding: CGFloat = Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(AppColor.bgRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(AppColor.hairline, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x05070F).opacity(0.6), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// Wraps the view in the standard raised card surface.
    func card(padding: CGFloat = Spacing.md) -> some View {
        modifier(CardModifier(padding: padding))
    }
}
