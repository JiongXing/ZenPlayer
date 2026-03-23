//
//  RecentPlaybackListView.swift
//  ZenPlayer
//
//  Created by Codex on 2026/3/23.
//

import SwiftUI
import Kingfisher

struct RecentPlaybackListView: View {
    @State private var recentPlaybackStore = RecentPlaybackStore.shared

    var body: some View {
        Group {
            if recentPlaybackStore.records.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .navigationTitle(L10n.text(.recentPlaybackTitle))
    }

    private var listView: some View {
        List {
            ForEach(recentPlaybackStore.records) { record in
                NavigationLink(value: record.context) {
                    RecentPlaybackRowView(record: record)
                }
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #endif
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(L10n.text(.recentPlaybackEmptyTitle), systemImage: "clock.badge.xmark")
        } description: {
            Text(L10n.text(.recentPlaybackEmptyMessage))
        }
    }
}

private struct RecentPlaybackRowView: View {
    let record: RecentPlaybackRecord

    private var episode: EpisodeItem { record.context.episode }

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(
                        episode.isVideo ? L10n.text(.episodeVideo) : L10n.text(.episodeAudio),
                        systemImage: episode.isVideo ? "video.fill" : "headphones"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Label(episode.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(L10n.string(.recentPlaybackPlayedAt, playedAtText))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if episode.isVideo, let url = URL(string: episode.coverUrl), !episode.coverUrl.isEmpty {
            KFImage(url)
                .placeholder {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.12))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                }
                .onFailureImage(PlatformImage.systemImage("play.rectangle"))
                .fade(duration: 0.2)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.12),
                                Color.orange.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "headphones")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.orange.opacity(0.6))
            }
            .frame(width: 72, height: 48)
        }
    }

    private var playedAtText: String {
        record.playedAt.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .hour()
                .minute()
        )
    }
}

#Preview {
    NavigationStack {
        RecentPlaybackListView()
    }
}
