//
//  MyView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI

struct MyView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 22) {
                    heroCard

                    VStack(spacing: 14) {
                        featureLink(
                            title: .myRecentPlayback,
                            detail: recentPlaybackDetail,
                            systemImage: "clock.arrow.circlepath",
                            tint: Color(red: 0.77, green: 0.57, blue: 0.39)
                        ) {
                            RecentPlaybackListView()
                        }

                        featureLink(
                            title: .myDownloadCompleted,
                            detail: downloadCompletedDetail,
                            systemImage: "checkmark.circle",
                            tint: Color(red: 0.38, green: 0.62, blue: 0.56)
                        ) {
                            CompletedDownloadListView()
                        }

                        featureLink(
                            title: .myAbout,
                            detail: versionDescription,
                            systemImage: "info.circle",
                            tint: Color(red: 0.58, green: 0.5, blue: 0.4)
                        ) {
                            AboutView()
                        }
                    }
                }
                .frame(maxWidth: min(max(proxy.size.width - 32, 0), 720))
                .frame(minHeight: proxy.size.height - 1, alignment: .top)
                .padding(.horizontal, LayoutConstants.horizontalPadding(sizeClass: sizeClass))
                .padding(.vertical, LayoutConstants.verticalPadding(sizeClass: sizeClass))
                .frame(maxWidth: .infinity)
            }
            .background(pageBackground.ignoresSafeArea())
        }
        .navigationTitle(L10n.text(.myTitle))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color(red: 0.92, green: 0.83, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Color(red: 0.57, green: 0.43, blue: 0.28))
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 6) {
                    Text(appDisplayName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color(red: 0.33, green: 0.25, blue: 0.17))

                    Text(L10n.text(.aboutDescription))
                        .font(.subheadline)
                        .foregroundStyle(ReadableSurfaceStyle.bodyText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ReadableSurfaceStyle.warmSurfaceTop,
                            Color(red: 0.976, green: 0.948, blue: 0.902),
                            ReadableSurfaceStyle.warmSurfaceBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(ReadableSurfaceStyle.surfaceStroke, lineWidth: 1)
        }
        .shadow(color: Color(red: 0.71, green: 0.56, blue: 0.39).opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private func featureLink<Destination: View>(
        title: L10nKey,
        detail: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.22),
                                    tint.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(tint)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(title))
                        .font(.headline)
                        .foregroundStyle(ReadableSurfaceStyle.titleText)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(ReadableSurfaceStyle.bodyText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ReadableSurfaceStyle.mutedText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ReadableSurfaceStyle.neutralSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ReadableSurfaceStyle.surfaceStroke, lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.08), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.98, blue: 0.96),
                Color(red: 0.95, green: 0.92, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: 240, height: 240)
                .blur(radius: 44)
                .offset(x: 56, y: -88)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(red: 0.84, green: 0.71, blue: 0.54).opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -70, y: 110)
        }
    }

    private var recentPlaybackDetail: String {
        L10n.string(.myRecentPlaybackSummary)
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Zen Player"
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    private var downloadCompletedDetail: String {
        L10n.string(.myDownloadCompletedSummary)
    }
}

#Preview {
    NavigationStack {
        MyView()
    }
}
