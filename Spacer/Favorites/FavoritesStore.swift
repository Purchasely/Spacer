//
//  FavoritesStore.swift
//  Spacer
//
//  Main-context CRUD on @MainActor. The @MainActor is itself serial, so a
//  synchronous count-then-insert is already atomic (no TOCTOU) — this is why we
//  use the main context, not a @ModelActor. The free cap is passed in from
//  EntitlementProvider; over-cap items are kept read-only via a pure derived
//  function, never a persisted lock flag.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class FavoritesStore {
    enum AddResult: Equatable {
        case inserted
        case alreadyExists
        case rejectedCapReached
    }

    private let context: ModelContext

    /// All favourites, newest first. Refreshed after each mutation so SwiftUI updates.
    private(set) var items: [FavoriteItem] = []

    init(context: ModelContext) {
        self.context = context
        // Control saves explicitly. Autosave fires on the run loop and, combined
        // with our explicit save() + the unique constraint, can crash mid-mutation;
        // an explicit save after each change is deterministic and testable.
        context.autosaveEnabled = false
        reload()
    }

    var count: Int { items.count }

    func isFavorite(_ contentType: FavoriteContentType, _ sourceID: String) -> Bool {
        let key = FavoriteItem.dedupKey(contentType, sourceID)
        return items.contains { $0.dedupKey == key }
    }

    /// Atomic add. `maxFavorites == nil` means unlimited. Returns whether the item
    /// was inserted, already present, or rejected because the cap was reached.
    @discardableResult
    func add(contentType: FavoriteContentType,
             sourceID: String,
             title: String,
             thumbnailURL: URL? = nil,
             fullURL: URL? = nil,
             isVideo: Bool = false,
             maxFavorites: Int?) -> AddResult {
        let key = FavoriteItem.dedupKey(contentType, sourceID)
        if items.contains(where: { $0.dedupKey == key }) {
            return .alreadyExists
        }
        if let maxFavorites, items.count >= maxFavorites {
            return .rejectedCapReached
        }
        let item = FavoriteItem(
            contentType: contentType,
            sourceID: sourceID,
            title: title,
            thumbnailURL: thumbnailURL,
            fullURL: fullURL,
            isVideo: isVideo
        )
        context.insert(item)
        save()
        reload()
        return .inserted
    }

    func remove(_ contentType: FavoriteContentType, _ sourceID: String) {
        let key = FavoriteItem.dedupKey(contentType, sourceID)
        guard let item = items.first(where: { $0.dedupKey == key }) else { return }
        context.delete(item)
        save()
        reload()
    }

    func remove(_ item: FavoriteItem) {
        context.delete(item)
        save()
        reload()
    }

    /// Canonical order: (dateAdded ASC, dedupKey ASC). The first `cap` are active;
    /// the remainder are read-only after a downgrade. Pure — no persisted flag.
    func isReadOnly(_ item: FavoriteItem, cap: Int?) -> Bool {
        guard let cap else { return false }
        let ordered = items.sorted {
            $0.dateAdded == $1.dateAdded ? $0.dedupKey < $1.dedupKey : $0.dateAdded < $1.dateAdded
        }
        guard let index = ordered.firstIndex(where: { $0.dedupKey == item.dedupKey }) else {
            return false
        }
        return index >= cap
    }

    private func reload() {
        let descriptor = FetchDescriptor<FavoriteItem>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        items = (try? context.fetch(descriptor)) ?? []
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // Never fatal on a user path. Unique-constraint collisions are benign
            // (we pre-check for duplicates); roll back anything else and log in debug.
            #if DEBUG
            print("[Spacer] FavoritesStore save failed: \(error)")
            #endif
            context.rollback()
        }
    }
}
