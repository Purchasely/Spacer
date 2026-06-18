//
//  CachedAsyncImage.swift
//  Spacer
//
//  SwiftUI front-end for ImageLoader. Uses `.task(id:)` so loads cancel on
//  disappear and restart when the URL changes — the prefetch/scroll-cancel
//  contract from the plan.
//

import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    var target: ImageLoader.Target = .detail
    var contentMode: ContentMode = .fill
    /// VoiceOver description. `nil` marks the image decorative (hidden).
    var accessibilityLabel: String? = nil
    /// When false, the loading and failure states render transparent (no shimmer
    /// or error chrome) so a lower-res image layered behind stays visible — used by
    /// the full-screen viewer to upgrade a cached preview to HD without a spinner.
    var showsLoadingPlaceholder: Bool = true

    @State private var image: UIImage?
    @State private var failed = false
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let image {
                loadedImage(image)
            } else if !showsLoadingPlaceholder {
                // Stay transparent so a lower-res layer behind shows through.
                Color.clear
            } else if failed {
                placeholder(systemImage: "photo.badge.exclamationmark")
            } else {
                placeholder(systemImage: nil)
                    .shimmering()
            }
        }
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityHidden(accessibilityLabel == nil)
        .task(id: url) {
            await load()
        }
    }

    @ViewBuilder
    private func loadedImage(_ image: UIImage) -> some View {
        switch contentMode {
        case .fill:
            // Fill via an overlay on a flexible Color.clear: the view takes the
            // PROPOSED size (never the image's huge pixel width), so it can't push
            // the surrounding layout wider than the screen. The image fills + clips.
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .transition(.opacity)
        case .fit:
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func placeholder(systemImage: String?) -> some View {
        Rectangle()
            .fill(AppColor.bgRaised)
            .overlay {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(AppColor.inkTertiary)
                }
            }
    }

    private func load() async {
        guard let url else {
            failed = true
            return
        }
        // Already showing this URL (e.g. returning to a tab) — no flash, no reload.
        if loadedURL == url, image != nil { return }
        // Different URL (e.g. a reused grid cell) — drop the stale image first.
        if loadedURL != url { image = nil }
        failed = false
        do {
            let loaded = try await ImageLoader.shared.image(from: url, target: target)
            withAnimation(.easeOut(duration: 0.25)) {
                image = loaded.image
            }
            loadedURL = url
        } catch is CancellationError {
            // View went away or URL changed; ignore.
        } catch {
            failed = true
        }
    }
}

// MARK: - Shimmer

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, AppColor.accent.opacity(0.10), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * 240)
                    .blendMode(.plusLighter)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}
