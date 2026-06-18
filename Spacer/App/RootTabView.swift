//
//  RootTabView.swift
//  Spacer
//
//  The 5-tab shell. EPIC lives inside Explore (confirmed); Favorites lives inside
//  Profile.
//

import SwiftUI
import UIKit

struct RootTabView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayView(service: app.apodService)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            ExploreView()
                .tabItem { Label("Explore", systemImage: "sparkles") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(AppColor.accent)
        .task { await app.presentOnboardingIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            // On foreground, pull any background renewals / cancellations, then re-check.
            guard phase == .active else { return }
            Task {
                await PurchaselyService.synchronize()
                await app.entitlements.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await ImageLoader.shared.clearMemory() }
        }
    }
}
