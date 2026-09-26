import SwiftUI

struct HomeResumeCard: View {
    let session: PlayerViewModel
    @State private var model: HomeResumeViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(session: PlayerViewModel) {
        self.session = session
        _model = State(initialValue: HomeResumeViewModel(progressStore: session.progressStore, queueStore: session.queueStore))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let candidate = model.candidate(session: session.session, position: session.currentPosition) {
                #if os(iOS)
                compactCard(candidate)
                    .padding(.bottom, 28)
                #else
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
                #endif
            }
        }
        .task(id: model.lookupContext) { await model.refresh() }
    }

    #if os(iOS)
    private func compactCard(_ candidate: ResumeCandidate) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(L10n.text(.resumeTitle), systemImage: "headphones")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("HomeAccent"))
                Spacer(minLength: 8)
                if candidate.kind == .active {
                    Text(session.sessionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    if let title = candidate.context.series?.title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                    Text(episodeTitle(candidate))
                        .font(.headline)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.string(.episodeFormat, candidate.context.episode.episode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if candidate.kind == .active { session.togglePlayback() }
                    else { session.continueListening(candidate.context) }
                } label: {
                    Group {
                        if candidate.kind == .active && session.session.phase == .preparing {
                            ProgressView().tint(Color("HomeBackground"))
                        } else {
                            Image(systemName: candidate.kind == .active && session.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3.weight(.semibold))
                        }
                    }
                    .foregroundStyle(Color("HomeBackground"))
                    .frame(width: 56, height: 56)
                    .background(Color("HomeAccent"), in: Circle())
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionText(candidate))
                .disabled(candidate.kind == .active && session.session.phase == .preparing)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let duration = candidate.duration, duration.isFinite, duration > 0,
                   candidate.position.isFinite {
                    ProgressView(value: min(max(candidate.position / duration, 0), 1))
                        .tint(Color("HomeAccent"))
                        .accessibilityHidden(true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack {
                        progressLabel(candidate)
                        Spacer(minLength: 12)
                        actionLabel(candidate)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        progressLabel(candidate)
                        actionLabel(candidate)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("HomeSurface"), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color("HomeAccent").opacity(0.12), lineWidth: 1)
        }
    }

    private func progressLabel(_ candidate: ResumeCandidate) -> some View {
        Text(progressText(candidate))
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func episodeTitle(_ candidate: ResumeCandidate) -> String {
        let episode = candidate.context.episode
        let title = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
        // 只省略接口标题中明确的集数尾缀，集数由下方独立文字展示。
        for suffix in ["-第\(episode.episode)集", "-第 \(episode.episode) 集"] where title.hasSuffix(suffix) {
            let name = String(title.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name }
        }
        return title
    }

    private func actionLabel(_ candidate: ResumeCandidate) -> some View {
        Text(actionText(candidate))
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color("HomeAccent"))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }
    #endif

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
