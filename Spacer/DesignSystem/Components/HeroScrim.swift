//
//  HeroScrim.swift
//  Spacer
//
//  Bottom-up gradient scrim so text stays legible over a full-bleed hero image.
//

import SwiftUI

struct HeroScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: AppColor.bgBase.opacity(0.35), location: 0.65),
                .init(color: AppColor.bgBase.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}
