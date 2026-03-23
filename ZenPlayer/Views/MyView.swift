//
//  MyView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI

struct MyView: View {
    @EnvironmentObject private var languageSettings: LanguageSettings
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var recentPlaybackStore = RecentPlaybackStore.shared

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
                            title: .myLanguage,
                            detail: currentLanguageDisplayName,
                            systemImage: "globe",
                            tint: Color(red: 0.48, green: 0.6, blue: 0.72)
                        ) {
                            LanguageSettingsView()
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
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    heroBadge(
                        title: .myRecentPlayback,
                        value: recentPlaybackCountText,
                        systemImage: "clock.arrow.circlepath"
                    )

                    heroBadge(
                        title: .myLanguage,
                        value: currentLanguageDisplayName,
                        systemImage: "globe"
                    )
                }

                VStack(spacing: 12) {
                    heroBadge(
                        title: .myRecentPlayback,
                        value: recentPlaybackCountText,
                        systemImage: "clock.arrow.circlepath"
                    )

                    heroBadge(
                        title: .myLanguage,
                        value: currentLanguageDisplayName,
                        systemImage: "globe"
                    )
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            Color(red: 0.97, green: 0.93, blue: 0.87),
                            Color(red: 0.94, green: 0.88, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.71, green: 0.56, blue: 0.39).opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private func heroBadge(title: L10nKey, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.67, green: 0.51, blue: 0.34))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.7))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text(title))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.33, green: 0.25, blue: 0.17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
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
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
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

    private var recentPlaybackCountText: String {
        "\(recentPlaybackStore.records.count)"
    }

    private var currentLanguageDisplayName: String {
        switch languageSettings.selectedLanguage.code {
        case "zh-Hans":
            return L10n.string(.settingsLanguageNameZhHans)
        case "zh-Hant":
            return L10n.string(.settingsLanguageNameZhHant)
        default:
            return languageSettings.selectedLanguage.code
        }
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
}

#Preview {
    NavigationStack {
        MyView()
    }
    .environmentObject(LanguageSettings())
}
