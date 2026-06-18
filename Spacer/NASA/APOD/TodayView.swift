//
//  TodayView.swift
//  Spacer
//

import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm: TodayViewModel

    // "Focusing the telescope" reveal + slow Ken-Burns drift.
    @State private var revealed = false
    @State private var drift = false
    @State private var showFullScreen = false

    init(service: any APODServicing) {
        _vm = State(initialValue: TodayViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                switch vm.phase {
                case .loading:
                    ScanningLoader(label: "ACQUIRING · APOD \(NASADate.string(from: NASADate.today))")
                        .padding(.top, Spacing.xxl)
                case .loaded(let apod):
                    content(apod)
                case .failed(let error):
                    ErrorStateView(
                        title: error.title,
                        message: error.message,
                        systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle",
                        retry: { Task { await vm.load() } }
                    )
                    .padding(.top, Spacing.xxl)
                }
            }
            .background(AppColor.bgBase)
            .filmGrain()
            .navigationTitle("Today")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
        .task { await vm.load() }
        .refreshable { await vm.load(force: true) }
    }

    @ViewBuilder
    private func content(_ apod: APOD) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            hero(apod)
                .fullScreenCover(isPresented: $showFullScreen) {
                    FullScreenImageView(
                        url: apod.hdurl ?? apod.url,
                        previewURL: apod.displayImageURL,
                        accessibilityLabel: apod.title
                    )
                }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(apod.title)
                    .font(AppFont.hero)
                    .foregroundStyle(AppColor.inkPrimary)
                    .offset(y: revealed ? 0 : 16)
                    .opacity(revealed ? 1 : 0)

                if let date = apod.parsedDate {
                    Text(NASADate.displayString(from: date).uppercased())
                        .font(AppFont.mono)
                        .foregroundStyle(AppColor.accent)
                }

                if let copyright = apod.copyright {
                    Text("© \(copyright.trimmingCharacters(in: .whitespacesAndNewlines))")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.inkTertiary)
                }

                actions(apod)

                Text(apod.explanation)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.inkSecondary)
                    .lineSpacing(4)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.xxl)
        .onAppear(perform: startReveal)
    }

    @ViewBuilder
    private func hero(_ apod: APOD) -> some View {
        CachedAsyncImage(
            url: apod.displayImageURL,
            target: .detail,
            contentMode: .fill,
            accessibilityLabel: "Astronomy Picture of the Day: \(apod.title)"
        )
        .frame(maxWidth: .infinity)
        .frame(height: 460)
        .scaleEffect(drift ? 1.08 : 1.0)
        .blur(radius: revealed ? 0 : 18)
        .opacity(revealed ? 1 : 0.65)
        .clipped()
        .overlay { HeroScrim() }
        .overlay(alignment: .topTrailing) {
            FavoriteButton(
                contentType: .apod,
                sourceID: apod.date,
                title: apod.title,
                thumbnailURL: apod.displayImageURL,
                fullURL: apod.hdurl ?? apod.url,
                isVideo: apod.isVideo
            )
            .padding(Spacing.sm)
        }
        .overlay(alignment: .bottomLeading) {
            if apod.isVideo {
                Label("Tap to play", systemImage: "play.circle.fill")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.inkPrimary)
                    .padding(Spacing.xs)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(Spacing.sm)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if apod.isVideo {
                openURL(apod.url)
            } else {
                showFullScreen = true
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(apod.isVideo ? "Plays the video" : "Opens full screen")
    }

    @ViewBuilder
    private func actions(_ apod: APOD) -> some View {
        HStack(spacing: Spacing.sm) {
            if apod.isVideo {
                Button {
                    openURL(apod.url)
                } label: {
                    Label("Play Video", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
            } else {
                // HD view is a premium gate; routed through the (Phase-1 no-op) gate
                // so it's wired for the Purchasely phase.
                Button {
                    Task {
                        await app.gate.attempt(.hdDownload, action: GatedAction(perform: {
                            if let hd = apod.hdurl { openURL(hd) }
                        }))
                    }
                } label: {
                    Label("View HD", systemImage: app.entitlements.isUnlocked(.hdDownload) ? "arrow.up.right.square" : "lock.fill")
                }
                .buttonStyle(.secondary)
            }
        }
    }

    private func startReveal() {
        guard !revealed else { return }
        if reduceMotion {
            revealed = true
            return
        }
        withAnimation(.easeOut(duration: 0.9)) {
            revealed = true
        }
        withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
            drift = true
        }
    }
}
