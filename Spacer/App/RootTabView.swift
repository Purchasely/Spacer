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
            guard phase == .active else { return }
            Task {
                // Observer mode must drive synchronize() itself (no server-side webhooks).
                // Full mode keeps state fresh server-side, and synchronize() there re-validates
                // the active receipt — emitting a spurious IN_APP_RESTORED on every foreground
                // (pollutes restore analytics / integrations). So in Full mode just read
                // userSubscriptions via refresh().
                if AppSettings.runningMode == .observer {
                    await PurchaselyService.synchronize()
                }
                await app.entitlements.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            Task { await ImageLoader.shared.clearMemory() }
        }
    }
}
