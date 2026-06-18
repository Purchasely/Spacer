//
//  ErrorStateView.swift
//  Spacer
//
//  Generic full-surface error state with a retry affordance. Distinct copy for
//  rate-limiting (429) vs offline is supplied by the caller.
//

import SwiftUI

struct ErrorStateView: View {
    let title: String
    var message: String?
    var systemImage: String = "exclamationmark.triangle"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppColor.hazard)
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
            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.primary)
                    .fixedSize()
                    .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}
