//
//  EmptyStateView.swift
//  Spacer
//
//  Empty states read as instrument readouts: a glyph, a serif headline, optional
//  detail, and an optional amber recovery action.
//

import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppColor.inkTertiary)
            Text(title)
                .font(AppFont.title)
                .foregroundStyle(AppColor.inkPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.secondary)
                    .fixedSize()
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}
