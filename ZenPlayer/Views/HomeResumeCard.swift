import SwiftUI

struct HomeResumeCard: View {
    let session: PlayerViewModel
    @State private var model: HomeResumeViewModel

    init(session: PlayerViewModel) {
        self.session = session
        _model = State(initialValue: HomeResumeViewModel(progressStore: session.progressStore, queueStore: session.queueStore))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let candidate = model.candidate(session: session.session, position: session.currentPosition) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text(.resumeTitle)).font(.headline)
                    if let title = candidate.context.series?.title, !title.isEmpty {
                        Text(title).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(candidate.context.episode.title).font(.title3).fixedSize(horizontal: false, vertical: true)
                    Text(L10n.string(.episodeFormat, candidate.context.episode.episode)).font(.caption)
                    Text(progressText(candidate)).font(.subheadline)
                    if candidate.kind == .active { Text(session.sessionStatus).font(.caption) }
                    Button {
                        if candidate.kind == .active { session.togglePlayback() }
                        else { session.continueListening(candidate.context) }
                    } label: {
                        Label(actionText(candidate), systemImage: candidate.kind == .active && session.isPlaying ? "pause.fill" : "play.fill")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(candidate.kind == .active && session.session.phase == .preparing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 24)
            }
        }
        .task(id: model.lookupContext) { await model.refresh() }
    }

    private func actionText(_ candidate: ResumeCandidate) -> String {
        if candidate.kind == .active {
            if session.session.phase == .preparing { return L10n.string(.sessionPreparing) }
            if session.isPlaying { return L10n.string(.sessionPause) }
        }
        return L10n.string(candidate.kind == .next ? .resumeNext : .resumeContinue)
    }

    private func progressText(_ candidate: ResumeCandidate) -> String {
        let position = EpisodeItem.formatPlaybackDuration(seconds: candidate.position)
        guard let duration = candidate.duration, duration.isFinite, duration > 0 else {
            return L10n.string(.progressUnknownDuration, position)
        }
        return L10n.string(.resumePosition, position, EpisodeItem.formatPlaybackDuration(seconds: duration))
    }
}
