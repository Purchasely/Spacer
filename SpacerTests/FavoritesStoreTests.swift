//
//  FavoritesStoreTests.swift
//  SpacerTests
//

import Testing
import SwiftData
@testable import Spacer

@MainActor
struct FavoritesStoreTests {
    private func makeStore() throws -> FavoritesStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FavoriteItem.self, configurations: config)
        return FavoritesStore(context: container.mainContext)
    }

    @Test func enforcesFreeCap() throws {
        let store = try makeStore()
        for i in 0..<5 {
            #expect(store.add(contentType: .apod, sourceID: "\(i)", title: "T", maxFavorites: 5) == .inserted)
        }
        #expect(store.count == 5)
        #expect(store.add(contentType: .apod, sourceID: "6", title: "T", maxFavorites: 5) == .rejectedCapReached)
        #expect(store.count == 5)
    }

    @Test func dedupesByKey() throws {
        let store = try makeStore()
        #expect(store.add(contentType: .epic, sourceID: "100", title: "Photo", maxFavorites: 5) == .inserted)
        #expect(store.add(contentType: .epic, sourceID: "100", title: "Photo", maxFavorites: 5) == .alreadyExists)
        #expect(store.count == 1)
    }

    @Test func unlimitedWhenCapIsNil() throws {
        let store = try makeStore()
        for i in 0..<20 {
            #expect(store.add(contentType: .epic, sourceID: "\(i)", title: "T", maxFavorites: nil) == .inserted)
        }
        #expect(store.count == 20)
    }

    @Test func removesByKey() throws {
        let store = try makeStore()
        _ = store.add(contentType: .epic, sourceID: "img1", title: "Earth", maxFavorites: 5)
        #expect(store.isFavorite(.epic, "img1") == true)
        store.remove(.epic, "img1")
        #expect(store.isFavorite(.epic, "img1") == false)
        #expect(store.count == 0)
    }

    @Test func overCapItemsAreReadOnlyAfterDowngrade() throws {
        let store = try makeStore()
        for i in 0..<8 {
            _ = store.add(contentType: .apod, sourceID: "\(i)", title: "T", maxFavorites: nil)
        }
        // With a cap of 5, the 3 newest become read-only; the 5 oldest stay active.
        let ordered = store.items.sorted {
            $0.dateAdded == $1.dateAdded ? $0.dedupKey < $1.dedupKey : $0.dateAdded < $1.dateAdded
        }
        let readOnlyCount = ordered.filter { store.isReadOnly($0, cap: 5) }.count
        #expect(readOnlyCount == 3)
    }
}
