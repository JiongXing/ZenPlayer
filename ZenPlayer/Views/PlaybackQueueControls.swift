import SwiftUI

struct PlaybackQueueControls<PlaylistButton: View>: View {
    @Environment(PlayerViewModel.self) private var session
    @ViewBuilder var playlistButton: () -> PlaylistButton

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 40) {
                Button { session.playAdjacent(-1) } label: {
                    Image(systemName: "backward.end.fill").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.text(.queuePrevious))
                .help(L10n.string(.queuePrevious))
                .disabled(!session.canPlayPrevious)
                playlistButton()
                Button { session.playAdjacent(1) } label: {
                    Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.text(.queueNext))
                .help(L10n.string(.queueNext))
                .disabled(!session.canPlayNext)
            }
            .buttonStyle(.plain)
            .font(.title3)

            if session.queue.snapshot?.isComplete != true {
                Text(session.queueStatus).font(.caption).foregroundStyle(.secondary)
            }
            if let notice = session.mediaSelectionNotice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
            }
            // 保存失败需要即时反馈，不能随设置折叠隐藏。
            if session.queueStore.saveError != nil {
                VStack(spacing: 4) {
                    Text(L10n.text(.queueSaveFailed)).font(.caption)
                    Button(L10n.text(.progressRetry)) { Task { await session.queueStore.flush() } }
                        .frame(minHeight: 44)
                }
            }
        }
    }
}
