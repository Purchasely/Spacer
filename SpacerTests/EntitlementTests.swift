//
//  EntitlementTests.swift
//  SpacerTests
//
//  Capability mapping for each entitlement status. The full state-machine
//  transitions land in Phase 2; here we verify the capability API the whole UI
//  reads — including grace-keeps-premium and the free cap.
//

import Testing
@testable import Spacer

@MainActor
struct EntitlementTests {
    @Test func freeTierLocksFeaturesAndFavorites() {
        let provider = EntitlementProvider(status: .free)
        #expect(provider.isPremium == false)
        // Favouriting is entirely a premium feature: free cap is 0.
        #expect(provider.favoriteCap == 0)
        for gate in FeatureGate.allCases {
            #expect(provider.isUnlocked(gate) == false)
        }
    }

    @Test func premiumUnlocksEverythingAndRemovesCap() {
        let provider = EntitlementProvider(status: .premiumActive)
        #expect(provider.isPremium == true)
        #expect(provider.favoriteCap == nil)
        for gate in FeatureGate.allCases {
            #expect(provider.isUnlocked(gate) == true)
        }
    }

    @Test func graceKeepsPremiumUnlocked() {
        let provider = EntitlementProvider(status: .grace)
        #expect(provider.isPremium == true)
        #expect(provider.favoriteCap == nil)
        #expect(provider.isUnlocked(.apodArchive) == true)
    }

    @Test func expiredRelocksToFreeCapabilities() {
        let provider = EntitlementProvider(status: .expired)
        #expect(provider.isPremium == false)
        #expect(provider.favoriteCap == 0)
        #expect(provider.isUnlocked(.hdDownload) == false)
    }

    @Test func everyGateMapsToAPlacement() {
        for gate in FeatureGate.allCases {
            #expect(gate.placement.isEmpty == false)
        }
    }
}
