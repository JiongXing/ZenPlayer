//
//  CompletedDownloadListView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI
import Kingfisher

struct CompletedDownloadListView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var downloadManager = DownloadManager.shared

    var body: some View {
        GeometryReader { proxy in
            contentView(for: proxy)
                .background(pageBackground.ignoresSafeArea())
        }
        .navigationTitle(L10n.text(.downloadCompletedTitle))
    }

    @ViewBuilder
    private func contentView(for proxy: GeometryProxy) -> some View {
        if downloadManager.completedDownloads.isEmpty {
            ScrollView {
                VStack(spacing: 20) {
                    emptyStateView(containerHeight: proxy.size.height)
                }
                .frame(maxWidth: min(max(proxy.size.width - 32, 0), 760))
                .frame(minHeight: proxy.size.height - 1, alignment: .top)
                .padding(.horizontal, LayoutConstants.horizontalPadding(sizeClass: sizeClass))
                .padding(.vertical, LayoutConstants.verticalPadding(sizeClass: sizeClass))
                .frame(maxWidth: .infinity)
            }
        } else {
#if os(iOS)
            iosCompletedListView(for: proxy)
#else
            macCompletedListView(for: proxy)
#endif
        }
    }

#if os(iOS)
    private func iosCompletedListView(for proxy: GeometryProxy) -> some View {
        let cardHorizontalInset = LayoutConstants.horizontalPadding(sizeClass: sizeClass)
        let horizontalPadding = LayoutConstants.horizontalPadding(sizeClass: sizeClass)
        let verticalPadding = LayoutConstants.verticalPadding(sizeClass: sizeClass)

        return VStack(spacing: 20) {
            summaryCard
                .padding(.horizontal, horizontalPadding)
                .padding(.top, verticalPadding)

            List {
                ForEach(downloadManager.completedDownloads) { item in
                    NavigationLink {
                        PlayerView(context: item.context)
                    } label: {
                        CompletedDownloadRowView(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label(L10n.string(.commonDelete), systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 7, leading: cardHorizontalInset, bottom: 7, trailing: cardHorizontalInset))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
#endif

    private func macCompletedListView(for proxy: GeometryProxy) -> some View {
        let cardHorizontalInset = LayoutConstants.horizontalPadding(sizeClass: sizeClass)

        return ScrollView {
            VStack(spacing: 20) {
                summaryCard
                    .padding(.horizontal, cardHorizontalInset)

                LazyVStack(spacing: 14) {
                    ForEach(downloadManager.completedDownloads) { item in
                        NavigationLink {
                            PlayerView(context: item.context)
                        } label: {
                            CompletedDownloadRowView(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(item)
                            } label: {
                                Label(L10n.string(.commonDelete), systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, cardHorizontalInset)
                    }
                }
            }
            .frame(minHeight: proxy.size.height - 1, alignment: .top)
            .padding(.vertical, LayoutConstants.verticalPadding(sizeClass: sizeClass))
            .frame(maxWidth: .infinity)
        }
    }

    private func delete(_ item: CompletedDownloadItem) {
        downloadManager.removeCompletedDownload(for: item.downloadKey)
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(red: 0.82, green: 0.92, blue: 0.87)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(red: 0.27, green: 0.55, blue: 0.46))
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(.downloadCompletedTitle))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.3, blue: 0.25))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(downloadManager.completedDownloads.count)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.49, blue: 0.41))

                Text(L10n.text(.myDownloadCompleted))
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
                            Color(red: 0.957, green: 0.982, blue: 0.967),
                            Color(red: 0.903, green: 0.952, blue: 0.919)
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
        .shadow(color: Color(red: 0.28, green: 0.54, blue: 0.45).opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private func emptyStateView(containerHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color(red: 0.88, green: 0.95, blue: 0.91)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color(red: 0.29, green: 0.57, blue: 0.47))
            }
            .frame(width: 78, height: 78)

            Text(L10n.text(.downloadCompletedEmptyTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.22, green: 0.3, blue: 0.25))

            Text(L10n.text(.downloadCompletedEmptyMessage))
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
        .shadow(color: Color(red: 0.28, green: 0.54, blue: 0.45).opacity(0.1), radius: 16, x: 0, y: 10)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.98, blue: 0.96),
                Color(red: 0.93, green: 0.96, blue: 0.92)
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
                .fill(Color(red: 0.58, green: 0.79, blue: 0.68).opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -76, y: 118)
        }
    }

}

private struct CompletedDownloadRowView: View {
    let item: CompletedDownloadItem

    @State private var isHovered = false

    private var episode: EpisodeItem { item.context.episode }
    private var mediaType: PlaybackMediaType { item.context.preferredMediaType ?? episode.fallbackMediaType }
    private var isVideoPlayback: Bool { mediaType.isVideo }
    private var accentColor: Color {
        isVideoPlayback
        ? Color(red: 0.39, green: 0.57, blue: 0.72)
        : Color(red: 0.36, green: 0.64, blue: 0.53)
    }

    var body: some View {
        HStack(spacing: 16) {
            thumbnailView

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    mediaTypeBadge
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

                    metaBadge(
                        text: episode.formattedDuration,
                        systemImage: "clock"
                    )
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
                                Color(red: 0.84, green: 0.94, blue: 0.89),
                                Color(red: 0.96, green: 0.99, blue: 0.97)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "headphones")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color(red: 0.3, green: 0.57, blue: 0.47))
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        CompletedDownloadListView()
    }
}
