//
//  FavoriteButton.swift
//  Spacer
//
//  Shared favourite toggle. Encapsulates the cap + gate contract: adding past the
//  free cap routes through the single FeatureGate path (no-op presenter in Phase 1,
//  so it simply stays capped). On success the image bytes are pinned for offline.
//

import SwiftUI

struct FavoriteButton: View {
    @Environment(AppModel.self) private var app

    let contentType: FavoriteContentType
    let sourceID: String
    let title: String
    var thumbnailURL: URL?
    var fullURL: URL?
    var isVideo: Bool = false

    private var isFavorite: Bool {
        app.favorites.isFavorite(contentType, sourceID)
    }

    /// Favouriting is a premium feature; free users see a lock.
    private var isPremium: Bool {
        app.entitlements.isUnlocked(.favoriteOverCap)
    }

    private var symbolName: String {
        if !isPremium { return "lock.fill" }
        return isFavorite ? "heart.fill" : "heart"
    }

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Image(systemName: symbolName)
                .symbolEffect(.bounce, value: isFavorite)
                .foregroundStyle(isFavorite && isPremium ? AppColor.accent : AppColor.inkSecondary)
                .padding(Spacing.xs)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if !isPremium { return "Favorites are a premium feature" }
        return isFavorite ? "Remove from favorites" : "Add to favorites"
    }

    private func toggle() async {
        // Free users: favouriting is gated — present the paywall (no-op in Phase 1).
        guard isPremium else {
            await app.gate.attempt(.favoriteOverCap, action: GatedAction(perform: { save() }))
            return
        }
        if isFavorite {
            app.favorites.remove(contentType, sourceID)
        } else {
            save()
        }
    }

    /// Saves the favourite (premium = unlimited) and pins its bytes for offline.
    private func save() {
        let result = app.favorites.add(
            contentType: contentType,
            sourceID: sourceID,
            title: title,
            thumbnailURL: thumbnailURL,
            fullURL: fullURL,
            isVideo: isVideo,
            maxFavorites: app.entitlements.favoriteCap
        )
        if result == .inserted, let url = fullURL ?? thumbnailURL {
            Task { await ImageLoader.shared.pin(url) }
        }
    }
}
