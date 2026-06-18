//
//  PrimaryButtonStyle.swift
//  Spacer
//

import SwiftUI

/// Filled amber primary action button.
struct PrimaryButtonStyle: ButtonStyle {
    var isProminent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body).weight(.semibold))
            .foregroundStyle(isProminent ? AppColor.bgBase : AppColor.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(isProminent ? AppColor.accent : AppColor.bgOverlay)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle(isProminent: true) }
    static var secondary: PrimaryButtonStyle { PrimaryButtonStyle(isProminent: false) }
}
