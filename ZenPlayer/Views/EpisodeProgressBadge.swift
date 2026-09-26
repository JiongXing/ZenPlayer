import SwiftUI

struct EpisodeProgressBadge: View {
    let context: PlaybackContext
    @Environment(PlayerViewModel.self) private var session

    var body: some View {
        let record = session.progressStore.record(for: context)
        Text(summary(record)).font(.caption).foregroundStyle(.secondary)
    }

    private func summary(_ record: PlaybackProgress?) -> String {
        guard let record, record.state != .notStarted else { return L10n.string(.resumeNotStarted) }
        if record.state == .completed { return L10n.string(.progressCompleted) }
        return L10n.string(.resumeListened, EpisodeItem.formatPlaybackDuration(seconds: record.positionSeconds))
    }
}
