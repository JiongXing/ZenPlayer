import SwiftUI

struct MiniPlayerView: View {
    @Environment(PlayerViewModel.self) private var session

    let openControls: () -> Void

    var body: some View {
        if let context = session.currentContext {
            HStack(spacing: 12) {
                Button { openControls() } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.episode.title).lineLimit(1).font(.headline)
                        Text("\(context.episode.episode) · \(session.sessionStatus)").lineLimit(1).font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(context.episode.title), \(context.episode.episode), \(session.sessionStatus)")
                Button { session.togglePlayback() } label: {
                    Image(systemName: session.session.phase == .failed ? "arrow.clockwise" : session.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text(session.session.phase == .failed ? .progressRetry : session.isPlaying ? .sessionPause : .sessionPlay))
                Menu {
                    Button(L10n.text(.sessionStop), role: .destructive) { session.stopPlayback() }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.text(.sessionMore))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.regularMaterial)
        }
    }
}

private struct PlayerControlsVisibilityKey: EnvironmentKey {
    static let defaultValue: (UUID, Bool) -> Void = { _, _ in }
}

extension EnvironmentValues {
    var playerControlsVisibility: (UUID, Bool) -> Void {
        get { self[PlayerControlsVisibilityKey.self] }
        set { self[PlayerControlsVisibilityKey.self] = newValue }
    }
}
