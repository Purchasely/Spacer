//
//  LoadingView.swift
//  Spacer
//
//  Loading states styled as instrument readouts: a "scanning" variable-color glyph
//  plus a monospaced status line. Reduce-Motion friendly (the symbol effect simply
//  doesn't animate).
//

import SwiftUI

struct ScanningLoader: View {
    var label: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppColor.accent)
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text(label)
                .font(AppFont.mono)
                .foregroundStyle(AppColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

/// A shimmering placeholder tile for image grids.
struct SkeletonTile: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            .fill(AppColor.bgRaised)
            .shimmering()
            .accessibilityHidden(true)
    }
}
