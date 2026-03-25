//
//  RecentPlaybackListView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI
import Kingfisher

struct RecentPlaybackListView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var recentPlaybackStore = RecentPlaybackStore.shared

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    if recentPlaybackStore.records.isEmpty {
                        emptyStateView(containerHeight: proxy.size.height)
                    } else {
                        summaryCard

                        LazyVStack(spacing: 14) {
                            ForEach(recentPlaybackStore.records) { record in
                                NavigationLink {
                                    PlayerView(context: record.context)
                                } label: {
                                    RecentPlaybackRowView(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: min(max(proxy.size.width - 32, 0), 760))
                .frame(minHeight: proxy.size.height - 1, alignment: .top)
                .padding(.horizontal, LayoutConstants.horizontalPadding(sizeClass: sizeClass))
                .padding(.vertical, LayoutConstants.verticalPadding(sizeClass: sizeClass))
                .frame(maxWidth: .infinity)
            }
            .background(pageBackground.ignoresSafeArea())
        }
        .navigationTitle(L10n.text(.recentPlaybackTitle))
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(red: 0.93, green: 0.84, blue: 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(red: 0.62, green: 0.46, blue: 0.29))
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(.recentPlaybackTitle))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.33, green: 0.25, blue: 0.17))

                if let latestRecord = recentPlaybackStore.records.first {
                    Text(latestRecord.progressSummaryText)
                        .font(.subheadline)
                        .foregroundStyle(ReadableSurfaceStyle.bodyText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(recentPlaybackStore.records.count)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.4, blue: 0.25))

                Text(L10n.text(.myRecentPlayback))
                    .font(.caption)
                    .foregroundStyle(ReadableSurfaceStyle.bodyText)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ReadableSurfaceStyle.warmSurfaceTop,
                            Color(red: 0.978, green: 0.95, blue: 0.908),
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

    private func emptyStateView(containerHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color(red: 0.95, green: 0.88, blue: 0.79)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color(red: 0.64, green: 0.49, blue: 0.31))
            }
            .frame(width: 78, height: 78)

            Text(L10n.text(.recentPlaybackEmptyTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.33, green: 0.25, blue: 0.17))

            Text(L10n.text(.recentPlaybackEmptyMessage))
                .font(.subheadline)
                .foregroundStyle(ReadableSurfaceStyle.bodyText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(containerHeight - 80, 320))
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ReadableSurfaceStyle.neutralSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ReadableSurfaceStyle.surfaceStroke, lineWidth: 1)
        }
        .shadow(color: Color(red: 0.71, green: 0.56, blue: 0.39).opacity(0.1), radius: 16, x: 0, y: 10)
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
                .offset(x: 60, y: -90)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(red: 0.84, green: 0.71, blue: 0.54).opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -76, y: 118)
        }
    }

}

private struct RecentPlaybackRowView: View {
    let record: RecentPlaybackRecord

    @State private var isHovered = false

    private var episode: EpisodeItem { record.context.episode }
    private var mediaType: PlaybackMediaType { record.context.preferredMediaType ?? episode.fallbackMediaType }
    private var isVideoPlayback: Bool { mediaType.isVideo }
    private var accentColor: Color {
        isVideoPlayback
        ? Color(red: 0.46, green: 0.58, blue: 0.74)
        : Color(red: 0.79, green: 0.56, blue: 0.33)
    }

    var body: some View {
        HStack(spacing: 16) {
            thumbnailView

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    mediaTypeBadge

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ReadableSurfaceStyle.mutedText)
                }

                Text(episode.title)
                    .font(.headline)
                    .foregroundStyle(ReadableSurfaceStyle.titleText)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if !episode.episode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        metaBadge(
                            text: L10n.string(.episodeFormat, episode.episode),
                            systemImage: "text.line.first.and.arrowtriangle.forward"
                        )
                    }

                    Text(record.progressSummaryText)
                        .font(.footnote)
                        .foregroundStyle(ReadableSurfaceStyle.bodyText)
                        .lineLimit(2)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ReadableSurfaceStyle.surfaceStroke, lineWidth: 1)
        }
        .shadow(color: accentColor.opacity(isHovered ? 0.16 : 0.1), radius: isHovered ? 16 : 12, x: 0, y: isHovered ? 12 : 8)
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.easeInOut(duration: 0.18), value: isHovered)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if isVideoPlayback, let url = URL(string: episode.coverUrl), !episode.coverUrl.isEmpty {
            KFImage(url)
                .placeholder {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.gray.opacity(0.12))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                }
                .onFailureImage(PlatformImage.systemImage("play.rectangle"))
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 92, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.85, blue: 0.73),
                                Color(red: 0.99, green: 0.95, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "headphones")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color(red: 0.76, green: 0.54, blue: 0.31))
            }
            .frame(width: 92, height: 66)
        }
    }

    private var mediaTypeBadge: some View {
        metaBadge(
            text: isVideoPlayback ? L10n.string(.episodeVideo) : L10n.string(.episodeAudio),
            systemImage: isVideoPlayback ? "video.fill" : "headphones",
            tint: accentColor
        )
    }

    private func metaBadge(text: String, systemImage: String, tint: Color = .secondary) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private var cardBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                ReadableSurfaceStyle.neutralSurface,
                accentColor.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    NavigationStack {
        RecentPlaybackListView()
    }
}
