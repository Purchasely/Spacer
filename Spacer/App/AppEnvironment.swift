//
//  AppEnvironment.swift
//  Spacer
//
//  The dependency-injection root. A single @Observable AppModel owns the services,
//  entitlement provider, gate coordinator, and favourites store, and is injected
//  via `.environment(_:)` (iOS 17 Observation) — no @Entry (that's iOS 18).
//

import Foundation
import SwiftData

@MainActor
@Observable
final class AppModel {
    let entitlements: EntitlementProvider
    let gate: FeatureGateCoordinator
    let favorites: FavoritesStore
    let paywalls: PurchaselyPaywallPresenter

    let apodService: any APODServicing

    /// Owned here (not in the view's @State) so the Explore feed loads once and
    /// survives tab switches / view rebuilds, instead of re-fetching on every visit.
    let exploreModel: ExploreViewModel

    init(modelContext: ModelContext) {
        let client = APIClient(apiKey: Secrets.nasaAPIKey)
        let entitlements = EntitlementProvider()
        self.entitlements = entitlements
        let paywalls = PurchaselyPaywallPresenter()
        self.paywalls = paywalls
        self.gate = FeatureGateCoordinator(entitlements: entitlements, presenter: paywalls)
        self.favorites = FavoritesStore(context: modelContext)
        let apodService = APODService(client: client)
        self.apodService = apodService
        self.exploreModel = ExploreViewModel(apodService: apodService)
    }

    /// Launch flow: check subscriptions, and if the user is definitively NOT
    /// subscribed, present the onboarding paywall. A failed / unknown check does
    /// not show it, so a subscriber is never paywalled because of a flaky network.
    func presentOnboardingIfNeeded() async {
        let active = await entitlements.refresh()
        guard active == false else { return }
        _ = await paywalls.present(placementId: "onboarding")
        // The user may have subscribed on the onboarding paywall (Full or Observer).
        await entitlements.refresh()
    }
}
