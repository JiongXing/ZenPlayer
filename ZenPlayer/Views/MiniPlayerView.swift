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
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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

private struct OpenPlayerControlsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openPlayerControls: () -> Void {
        get { self[OpenPlayerControlsKey.self] }
        set { self[OpenPlayerControlsKey.self] = newValue }
    }
}

private struct MiniPlayerInset: ViewModifier {
    @Environment(PlayerViewModel.self) private var session
    @Environment(\.openPlayerControls) private var openControls

    func body(content: Content) -> some View {
        // 放在浏览页内容内，继承 Tab／导航的实际安全区；完整播放页不应用此修饰器。
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if session.hasSession {
                MiniPlayerView(openControls: openControls)
            }
        }
    }
}

extension View {
    func miniPlayerInset() -> some View {
        modifier(MiniPlayerInset())
    }
}
