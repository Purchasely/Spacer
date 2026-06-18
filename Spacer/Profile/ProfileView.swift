//
//  ProfileView.swift
//  Spacer
//
//  Subscription status, favourites entry, notification toggles (premium gates,
//  wired through the no-op presenter in Phase 1), and legal links. The real
//  Restore / Manage Subscription actions arrive in Phase 2.
//

import SwiftUI

/// Lightweight identifiable payload for the restore-result alert.
private struct RestoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ProfileView: View {
    @Environment(AppModel.self) private var app

    @State private var isRestoring = false
    @State private var restoreAlert: RestoreAlert?

    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://api.nasa.gov")!

    var body: some View {
        NavigationStack {
            List {
                statusSection
                favoritesSection
                notificationsSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.bgBase)
            .navigationTitle("Profile")
            .alert(item: $restoreAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private var statusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(app.entitlements.isPremium ? "Spacer Premium" : "Free")
                        .font(AppFont.heading)
                        .foregroundStyle(AppColor.inkPrimary)
                    Text(app.entitlements.isPremium ? "Full access unlocked" : "Upgrade to unlock the full universe")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.inkSecondary)
                }
                Spacer()
                Image(systemName: app.entitlements.isPremium ? "checkmark.seal.fill" : "sparkles")
                    .foregroundStyle(AppColor.accent)
                    .font(.title2)
            }
            .listRowBackground(AppColor.bgRaised)

            restoreButton
        } header: {
            Text("Subscription")
        } footer: {
            Text("Already subscribed? Restore your purchase on a new device or after reinstalling.")
                .font(AppFont.caption)
        }
    }

    private var restoreButton: some View {
        Button(action: restore) {
            HStack {
                Text("Restore Purchases").foregroundStyle(AppColor.inkPrimary)
                Spacer()
                if isRestoring {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(AppColor.accent)
                }
            }
        }
        .disabled(isRestoring)
        .listRowBackground(AppColor.bgRaised)
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            let ok = await PurchaselyService.restorePurchases()
            if ok { await app.entitlements.refresh() }
            isRestoring = false
            restoreAlert = ok
                ? RestoreAlert(title: "Restore Complete", message: "Any previous purchases have been restored.")
                : RestoreAlert(title: "Nothing to Restore", message: "We couldn't find a previous purchase to restore.")
        }
    }

    private var favoritesSection: some View {
        let isUnlocked = app.entitlements.isUnlocked(.favoriteOverCap)
        return Section {
            if isUnlocked {
                NavigationLink {
                    FavoritesView()
                } label: {
                    Label("Favorites", systemImage: "heart.fill")
                    Spacer()
                    Text("\(app.favorites.count)")
                        .font(AppFont.mono)
                        .foregroundStyle(AppColor.inkSecondary)
                }
                .listRowBackground(AppColor.bgRaised)
            } else {
                Button {
                    Task { await app.gate.attempt(.favoriteOverCap, action: GatedAction(perform: {})) }
                } label: {
                    HStack {
                        Label("Favorites", systemImage: "heart.fill")
                            .foregroundStyle(AppColor.inkPrimary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(AppColor.inkTertiary)
                    }
                }
                .listRowBackground(AppColor.bgRaised)
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            gatedToggle("Daily picture reminder", gate: .dailyNotif) {
                Task { await NotificationService.sendDailyPictureReminder() }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("A premium feature. Tap to send yourself a test reminder — it arrives in about 5 seconds.")
                .font(AppFont.caption)
        }
    }

    private func gatedToggle(_ title: String, gate: FeatureGate, perform: @escaping () -> Void) -> some View {
        let isUnlocked = app.entitlements.isUnlocked(gate)
        return Button {
            Task { await app.gate.attempt(gate, action: GatedAction(perform: perform)) }
        } label: {
            HStack {
                Text(title).foregroundStyle(AppColor.inkPrimary)
                Spacer()
                Image(systemName: isUnlocked ? "bell.fill" : "lock.fill")
                    .foregroundStyle(isUnlocked ? AppColor.accent : AppColor.inkTertiary)
            }
        }
        .listRowBackground(AppColor.bgRaised)
    }

    private var aboutSection: some View {
        Section {
            Link(destination: termsURL) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            .listRowBackground(AppColor.bgRaised)
            Link(destination: privacyURL) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            .listRowBackground(AppColor.bgRaised)
            HStack {
                Text("Data source")
                Spacer()
                Text("NASA Open APIs").foregroundStyle(AppColor.inkSecondary)
            }
            .listRowBackground(AppColor.bgRaised)
        } header: {
            Text("About")
        }
    }
}
