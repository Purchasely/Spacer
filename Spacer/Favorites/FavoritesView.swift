//
//  FavoritesView.swift
//  Spacer
//
//  Heterogeneous favourites grid. The 5-item free cap is enforced at save time by
//  FavoritesStore + EntitlementProvider (no paywall yet in Phase 1). Over-cap items
//  render read-only (a Phase 2 downgrade concern; the derived flag is wired now).
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppModel.self) private var app
    @State private var fullImage: FavoriteItem?

    private let grid = [GridItem(.flexible(), spacing: Spacing.xs),
                        GridItem(.flexible(), spacing: Spacing.xs)]

    var body: some View {
        Group {
            if app.favorites.items.isEmpty {
                EmptyStateView(
                    systemImage: app.entitlements.isPremium ? "heart" : "lock.fill",
                    title: app.entitlements.isPremium ? "No favorites yet" : "Favorites are premium",
                    message: app.entitlements.isPremium
                        ? "Tap the heart on any image to save it here for offline viewing."
                        : "Upgrade to save images and view them offline."
                )
            } else {
                ScrollView {
                    capHeader
                    LazyVGrid(columns: grid, spacing: Spacing.xs) {
                        ForEach(app.favorites.items) { item in
                            tile(item)
                        }
                    }
                    .padding(Spacing.xs)
                }
            }
        }
        .background(AppColor.bgBase)
        .filmGrain()
        .navigationTitle("Favorites")
        .sheet(item: $fullImage) { item in
            FavoriteDetailView(item: item)
        }
    }

    @ViewBuilder
    private var capHeader: some View {
        if let cap = app.entitlements.favoriteCap {
            Text("\(app.favorites.count) / \(cap) SAVED · FREE TIER")
                .font(AppFont.mono)
                .foregroundStyle(AppColor.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
        }
    }

    private func tile(_ item: FavoriteItem) -> some View {
        let readOnly = app.favorites.isReadOnly(item, cap: app.entitlements.favoriteCap)
        return CachedAsyncImage(url: item.thumbnailURL ?? item.fullURL, target: .grid)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(alignment: .topLeading) {
                Image(systemName: icon(for: item.contentType))
                    .font(.caption)
                    .foregroundStyle(AppColor.inkPrimary)
                    .padding(Spacing.xs)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(Spacing.xs)
            }
            .overlay(alignment: .bottomLeading) {
                Text(item.title)
                    .font(AppFont.caption)
                    .lineLimit(2)
                    .foregroundStyle(AppColor.inkPrimary)
                    .padding(Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
            }
            .opacity(readOnly ? 0.5 : 1)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .onTapGesture { fullImage = item }
            .contextMenu {
                Button(role: .destructive) {
                    app.favorites.remove(item)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(.isButton)
    }

    private func icon(for type: FavoriteContentType) -> String {
        switch type {
        case .apod: "sparkles"
        case .epic: "globe.europe.africa"
        }
    }
}

private struct FavoriteDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let item: FavoriteItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if item.isVideo {
                        EmptyStateView(systemImage: "play.rectangle", title: item.title,
                                       message: "This favorite is a video.")
                    } else {
                        CachedAsyncImage(url: item.fullURL ?? item.thumbnailURL, target: .detail, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    Text(item.title)
                        .font(AppFont.title)
                        .foregroundStyle(AppColor.inkPrimary)
                    Text("\(item.contentType.rawValue.uppercased()) · SAVED \(NASADate.displayString(from: item.dateAdded))")
                        .font(AppFont.mono)
                        .foregroundStyle(AppColor.inkSecondary)
                }
                .padding(Spacing.md)
            }
            .background(AppColor.bgBase)
            .navigationTitle("Favorite")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        app.favorites.remove(item)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
        }
    }
}
