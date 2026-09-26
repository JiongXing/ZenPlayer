import SwiftUI

/// 当前会话的队列展示；不拥有播放器或另行加载讲集。
struct PlayerPlaylistView: View {
    let openSeries: (SeriesDestination) -> Void

    @Environment(PlayerViewModel.self) private var session
    @Environment(\.dismiss) private var dismiss

    private var snapshot: QueueSnapshot? { session.queue.snapshot }

    private var seriesDestination: SeriesDestination? {
        guard let current = session.currentContext else { return nil }
        if let snapshot {
            return SeriesDestination(id: snapshot.seriesID, title: snapshot.title,
                                     url: snapshot.detailURL, targetEpisodeID: current.episode.id)
        }
        guard let reference = current.series, !reference.detailURL.isEmpty else { return nil }
        return SeriesDestination(reference: reference, targetEpisodeID: current.episode.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.text(.playerPlaylist)).font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text(.playerPlaylistClose))
                .accessibilityIdentifier("player.playlist.close")
            }
            .padding(.horizontal)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                if let destination = seriesDestination {
                    Text(destination.title)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Button { openSeries(destination) } label: {
                        Label(L10n.text(.playerSeriesDetails), systemImage: "arrow.up.right")
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("player.playlist.series")
                } else {
                    Text(L10n.text(.playerSeriesUnavailable)).foregroundStyle(.secondary)
                }
                Text(session.queueStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()
            ScrollViewReader { proxy in
                List {
                    if let snapshot {
                        ForEach(snapshot.episodes) { episode in
                            episodeRow(episode, snapshotID: snapshot.id)
                        }
                    } else if let current = session.currentContext {
                        episodeRow(current.episode, snapshotID: nil)
                    }
                }
                .listStyle(.plain)
                .onAppear { scrollToCurrent(using: proxy) }
                .onChange(of: snapshot?.id) { _, _ in scrollToCurrent(using: proxy) }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, idealWidth: 480, minHeight: 420, idealHeight: 560)
        #endif
    }

    private func episodeRow(_ episode: EpisodeItem, snapshotID: String?) -> some View {
        let isCurrent = episode.id == session.currentContext?.episode.id
        return Button {
            if let snapshotID { session.playEpisode(id: episode.id, snapshotID: snapshotID) }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !episode.episode.isEmpty {
                        Text(L10n.string(.episodeFormat, episode.episode))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCurrent ? L10n.string(.playerPlaylistCurrent) : "")
        .accessibilityIdentifier("player.playlist.episode.\(episode.id)")
        .id(episode.id)
    }

    private func scrollToCurrent(using proxy: ScrollViewProxy) {
        if let id = session.currentContext?.episode.id { proxy.scrollTo(id, anchor: .center) }
    }
}
