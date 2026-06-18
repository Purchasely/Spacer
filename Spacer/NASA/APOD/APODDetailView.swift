//
//  APODDetailView.swift
//  Spacer
//
//  Reusable APOD detail sheet (used from Explore and Favorites).
//

import SwiftUI

struct APODDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let apod: APOD

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    CachedAsyncImage(
                        url: apod.displayImageURL,
                        target: .detail,
                        contentMode: .fit,
                        accessibilityLabel: apod.title
                    )
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            if apod.isVideo {
                                Button {
                                    openURL(apod.url)
                                } label: {
                                    Label("Play Video", systemImage: "play.fill")
                                }
                                .buttonStyle(.primary)
                                .padding(Spacing.sm)
                            }
                        }

                    Text(apod.title)
                        .font(AppFont.title)
                        .foregroundStyle(AppColor.inkPrimary)

                    if let date = apod.parsedDate {
                        Text(NASADate.displayString(from: date).uppercased())
                            .font(AppFont.mono)
                            .foregroundStyle(AppColor.accent)
                    }

                    Text(apod.explanation)
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.inkSecondary)
                        .lineSpacing(4)
                }
                .padding(Spacing.md)
            }
            .background(AppColor.bgBase)
            .navigationTitle("Picture of the Day")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    FavoriteButton(
                        contentType: .apod,
                        sourceID: apod.date,
                        title: apod.title,
                        thumbnailURL: apod.displayImageURL,
                        fullURL: apod.hdurl ?? apod.url,
                        isVideo: apod.isVideo
                    )
                }
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
            }
        }
    }
}
