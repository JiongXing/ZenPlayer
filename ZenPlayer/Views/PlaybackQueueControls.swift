import SwiftUI

struct PlaybackQueueControls: View {
    @Environment(PlayerViewModel.self) private var session

    var body: some View {
        @Bindable var store = session.queueStore
        VStack(alignment: .leading, spacing: 10) {
            Text(session.queueStatus).font(.caption).foregroundStyle(.secondary)
            if let notice = session.mediaSelectionNotice {
                Text(notice).font(.caption)
            }
            HStack {
                Button { session.playAdjacent(-1) } label: {
                    Label(L10n.text(.queuePrevious), systemImage: "backward.end.fill")
                        .frame(minHeight: 44)
                }
                .disabled(!session.canPlayPrevious)
                Spacer()
                Button { session.playAdjacent(1) } label: {
                    Label(L10n.text(.queueNext), systemImage: "forward.end.fill")
                        .frame(minHeight: 44)
                }
                .disabled(!session.canPlayNext)
            }
            Toggle(L10n.text(.queueAutoAdvance), isOn: $store.autoAdvance)
            if store.saveError != nil {
                HStack {
                    Text(L10n.text(.queueSaveFailed)).font(.caption)
                    Button(L10n.text(.progressRetry)) { Task { await store.flush() } }
                }
            }
        }
    }
}
