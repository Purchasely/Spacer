//
//  FullScreenImageView.swift
//  Spacer
//
//  Full-screen image viewer with pinch-to-zoom and double-tap. Presented over a
//  black backdrop; dismiss with the close button.
//

import SwiftUI

struct FullScreenImageView: View {
    @Environment(\.dismiss) private var dismiss
    /// High-resolution image to display (loads at up to 2048 px for crisp zoom).
    let url: URL?
    /// Lower-res image already on screen (and in cache) when this opened. Shown
    /// instantly underneath so there's no spinner while the HD version loads.
    var previewURL: URL?
    var accessibilityLabel: String?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                // Cached preview: renders immediately from memory, no network.
                if let previewURL {
                    CachedAsyncImage(
                        url: previewURL,
                        target: .detail,
                        contentMode: .fit
                    )
                }
                // HD upgrade: transparent while loading, cross-fades in on top.
                CachedAsyncImage(
                    url: url,
                    target: .custom(maxPixel: 2048),
                    contentMode: .fit,
                    accessibilityLabel: accessibilityLabel,
                    showsLoadingPlaceholder: false
                )
            }
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in scale = max(1, lastScale * value) }
                    .onEnded { _ in lastScale = scale }
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = scale > 1 ? 1 : 2.5
                    lastScale = scale
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9), .black.opacity(0.4))
            }
            .padding(Spacing.md)
            .accessibilityLabel("Close")
        }
        .statusBarHidden()
    }
}
