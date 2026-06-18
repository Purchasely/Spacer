//
//  ExploreView.swift
//  Spacer
//

import SwiftUI

struct ExploreView: View {
    @Environment(AppModel.self) private var app
    @State private var apodDetail: APOD?
    @Namespace private var zoom

    /// App-owned so the loaded feed persists across tab switches (see AppModel).
    private var vm: ExploreViewModel { app.exploreModel }

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.isLoading && vm.apods.isEmpty {
                    ScanningLoader(label: "SCANNING · RECENT IMAGERY")
                        .padding(.top, Spacing.xxl)
                } else if let error = vm.loadError, vm.apods.isEmpty {
                    ErrorStateView(title: error.title, message: error.message,
                                   retry: { Task { await vm.load() } })
                    .padding(.top, Spacing.xxl)
                } else {
                    LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                        ForEach(vm.apods) { apod in
                            apodCard(apod)
                        }
                        collectionsButton
                            .padding(.top, Spacing.sm)
                    }
                    .padding(Spacing.md)
                }
            }
            .background(AppColor.bgBase)
            .filmGrain()
            .navigationTitle("Explore")
            .sheet(item: $apodDetail) { apod in
                APODDetailView(apod: apod).zoomDestination(id: apod.id, in: zoom)
            }
        }
        .task { if vm.apods.isEmpty { await vm.load() } }
    }

    // MARK: - APOD feed (single-column cards)

    private func apodCard(_ apod: APOD) -> some View {
        Button {
            apodDetail = apod
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CachedAsyncImage(
                    url: apod.displayImageURL,
                    target: .detail,
                    contentMode: .fill,
                    accessibilityLabel: apod.title
                )
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if apod.isVideo {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(AppColor.inkPrimary)
                            .padding(Spacing.xs)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(apod.title)
                        .font(AppFont.heading)
                        .foregroundStyle(AppColor.inkPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let date = apod.parsedDate {
                        Text(NASADate.displayString(from: date).uppercased())
                            .font(AppFont.mono)
                            .foregroundStyle(AppColor.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
        .zoomSource(id: apod.id, in: zoom)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var collectionsButton: some View {
        Button {
            Task { await app.gate.attempt(.exploreDepth, action: GatedAction(perform: {})) }
        } label: {
            Label(
                app.entitlements.isUnlocked(.exploreDepth) ? "Open Collections" : "Unlock Collections",
                systemImage: app.entitlements.isUnlocked(.exploreDepth) ? "square.stack.3d.up" : "lock.fill"
            )
        }
        .buttonStyle(.secondary)
    }
}
