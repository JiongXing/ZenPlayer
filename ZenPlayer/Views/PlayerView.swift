//
//  PlayerView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/22.
//

import SwiftUI
import AVKit

/// 播放页：支持视频/音频播放与音频处理控制
struct PlayerView: View {
    let context: PlaybackContext
    var selectsOnAppear = true

    @Environment(PlayerViewModel.self) private var viewModel
    @State private var didSelect = false
    @State private var showsPlaylist = false
    @State private var pendingSeriesDestination: SeriesDestination?
    @State private var seriesDestination: SeriesDestination?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let current = viewModel.currentContext {
                    Text(current.episode.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let player = viewModel.player {
                    mediaPlayerArea(player: player)
                } else if viewModel.session.phase != .failed {
                    Group {
                        if viewModel.isPreparingPlayback {
                            if viewModel.showsLoading { ProgressView(L10n.text(.playerLoading)) }
                            else { Text(viewModel.sessionStatus) }
                        } else {
                            Text(L10n.text(.sessionStopped))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                }

                // 失败与加载反馈不依赖原生控件，保留明确的恢复入口。
                if viewModel.session.phase == .failed {
                    errorView(message: viewModel.sessionStatus)
                } else if viewModel.player != nil && viewModel.showsLoading {
                    ProgressView(L10n.text(.playerLoading))
                } else if viewModel.session.phase == .ended {
                    Text(viewModel.sessionStatus).font(.caption).foregroundStyle(.secondary)
                }

                if viewModel.hasSession {
                    PlaybackQueueControls { playlistButton }
                }
                ProgressSaveNotice(store: viewModel.progressStore)

                if viewModel.canSwitchMediaType {
                    mediaTypeSwitcher
                }
                if viewModel.hasSession {
                    PlayerSettingsView()
                }
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .background(pageBackground)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if viewModel.hasSession {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(L10n.text(.sessionStop), role: .destructive) { viewModel.stopPlayback() }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.text(.sessionMore))
                    .accessibilityIdentifier("player.more")
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showsPlaylist, onDismiss: finishPlaylistDismissal) {
            playlistPanel
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        #endif
        .navigationDestination(item: $seriesDestination) { destination in
            SeriesDetailView(destination: destination)
                .miniPlayerInset()
        }
        .onChange(of: viewModel.hasSession) { _, hasSession in
            if !hasSession {
                pendingSeriesDestination = nil
                showsPlaylist = false
            }
        }
        .onAppear {
            if selectsOnAppear && !didSelect {
                didSelect = true
                viewModel.selectPlayback(context)
            }
        }
    }

    private var playlistButton: some View {
        Button { showsPlaylist = true } label: {
            Image(systemName: "list.bullet")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text(.playerPlaylist))
        .accessibilityIdentifier("player.playlist")
        .help(L10n.string(.playerPlaylist))
        #if os(macOS)
        .popover(isPresented: $showsPlaylist, arrowEdge: .bottom) {
            playlistPanel.onDisappear(perform: finishPlaylistDismissal)
        }
        #endif
    }

    private var playlistPanel: some View {
        PlayerPlaylistView { destination in
            pendingSeriesDestination = destination
            showsPlaylist = false
        }
    }

    private func finishPlaylistDismissal() {
        seriesDestination = pendingSeriesDestination
        pendingSeriesDestination = nil
    }

    private var mediaTypeSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.availableMediaTypes) { mediaType in
                Button {
                    Task { await viewModel.switchMediaType(to: mediaType) }
                } label: {
                    Text(mediaTypeLabel(for: mediaType))
                        .font(.subheadline.weight(viewModel.selectedMediaType == mediaType ? .semibold : .regular))
                        .padding(.horizontal, 24)
                        .frame(minWidth: 88, minHeight: 44)
                        .background {
                            if viewModel.selectedMediaType == mediaType {
                                RoundedRectangle(cornerRadius: 8).fill(.background)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.selectedMediaType == mediaType ? .isSelected : [])
                .accessibilityIdentifier("player.media.\(mediaType.rawValue)")
                .disabled(viewModel.isPreparingPlayback)
            }
        }
        .padding(4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Label(L10n.text(.playerCannotPlay), systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { viewModel.togglePlayback() } label: {
                Label(L10n.text(.progressRetry), systemImage: "arrow.clockwise")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("player.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func mediaPlayerArea(player: AVPlayer) -> some View {
        if viewModel.isVideo {
            playerSurface(player: player)
                .frame(maxWidth: .infinity)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .playerSurfaceStyle()
        } else {
            playerSurface(player: player)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .playerSurfaceStyle()
        }
    }

    @ViewBuilder
    private func playerSurface(player: AVPlayer) -> some View {
        Group {
            #if os(iOS)
            AVPlayerContainerView(player: player)
            #else
            VideoPlayer(player: player)
            #endif
        }
        .id(viewModel.selectedMediaType)
    }

    private var pageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    private func mediaTypeLabel(for mediaType: PlaybackMediaType) -> String {
        switch mediaType {
        case .audio:
            return L10n.string(.episodeAudio)
        case .video:
            return L10n.string(.episodeVideo)
        }
    }


}

private extension View {
    func playerSurfaceStyle() -> some View {
        background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - iOS AVPlayer 容器（含全屏按钮）

#if os(iOS)
struct AVPlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> UIViewController {
        let container = PlayerContainerViewController()
        container.player = player
        return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let container = uiViewController as? PlayerContainerViewController else { return }
        container.configure(player: player)
    }
}

/// 承载 AVPlayerViewController 的容器
final class PlayerContainerViewController: UIViewController {
    var player: AVPlayer!

    private var playerVC: AVPlayerViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.allowsPictureInPicturePlayback = true
        if #available(iOS 14.2, *) {
            playerVC.canStartPictureInPictureAutomaticallyFromInline = true
        }

        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerVC.didMove(toParent: self)

        // 播放意图由模型在恢复成功后执行。
    }

    func configure(player: AVPlayer) {
        guard isViewLoaded else {
            self.player = player
            return
        }
        if self.player !== player {
            self.player = player
            playerVC.player = player
            // 播放意图由模型在恢复成功后执行。
        }
    }

    // 不在这里强制暂停，避免 App 进后台时被误判为页面离开。
}
#endif
