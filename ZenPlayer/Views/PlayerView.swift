//
//  PlayerView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/22.
//

import SwiftUI
import AVKit

/// 播放页：支持视频/音频播放，带全屏按钮（点击进入横屏全屏）
struct PlayerView: View {
    let context: PlaybackContext

    @State private var viewModel = PlayerViewModel()

    var body: some View {
        VStack(spacing: 14) {
            if let player = viewModel.player {
                mediaPlayerArea(player: player)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, minHeight: 220)
            }

            if viewModel.player != nil {
                controlPanel
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(pageBackground)
        .navigationBarBackButtonHidden(false)
        .task(id: context.id) {
            await viewModel.preparePlayback(episode: context.episode, serverUrl: context.serverUrl)
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("无法播放")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func mediaPlayerArea(player: AVPlayer) -> some View {
        Group {
            #if os(iOS)
            AVPlayerContainerView(
                player: player,
                isVideo: viewModel.isVideo,
                episodeTitle: context.episode.title
            )
            #else
            VideoPlayer(player: player)
            #endif
        }
        .frame(maxWidth: .infinity)
        .frame(height: viewModel.isVideo ? 260 : 220)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("降噪")
                    .font(.subheadline)
                    .foregroundStyle(.black)
                Spacer()
                Toggle("降噪开关", isOn: $viewModel.denoiseEnabled)
                    .tint(.black)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("音量放大")
                    .font(.subheadline)
                    .foregroundStyle(.black)

                HStack(spacing: 8) {
                    ForEach(PlayerViewModel.supportedAmplificationOptions, id: \.self) { option in
                        Button {
                            viewModel.amplificationMultiplier = option
                        } label: {
                            Text(PlayerViewModel.amplificationLabel(option))
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(viewModel.amplificationMultiplier == option ? .white : .black)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(viewModel.amplificationMultiplier == option ? Color.black : Color.black.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        )
    }

    private var pageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

// MARK: - iOS AVPlayer 容器（含全屏按钮）

#if os(iOS)
struct AVPlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let isVideo: Bool
    let episodeTitle: String

    func makeUIViewController(context: Context) -> UIViewController {
        let container = PlayerContainerViewController()
        container.player = player
        container.isVideo = isVideo
        container.episodeTitle = episodeTitle
        return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let container = uiViewController as? PlayerContainerViewController else { return }
        container.configure(player: player, isVideo: isVideo, episodeTitle: episodeTitle)
    }
}

/// 承载 AVPlayerViewController 的容器，带全屏按钮
final class PlayerContainerViewController: UIViewController {
    var player: AVPlayer!
    var isVideo: Bool = true
    var episodeTitle: String = ""

    private var playerVC: AVPlayerViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true

        if isVideo, let overlay = playerVC.contentOverlayView {
            let fullscreenButton = UIButton(type: .system)
            fullscreenButton.setImage(
                UIImage(systemName: "arrow.up.left.and.arrow.down.right")?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)),
                for: .normal
            )
            fullscreenButton.tintColor = .white
            fullscreenButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
            fullscreenButton.layer.cornerRadius = 22
            fullscreenButton.clipsToBounds = true
            fullscreenButton.addTarget(self, action: #selector(enterFullscreenTapped), for: .touchUpInside)
            fullscreenButton.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(fullscreenButton)
            NSLayoutConstraint.activate([
                fullscreenButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -16),
                fullscreenButton.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -60),
                fullscreenButton.widthAnchor.constraint(equalToConstant: 44),
                fullscreenButton.heightAnchor.constraint(equalToConstant: 44)
            ])
        }

        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerVC.didMove(toParent: self)

        player.play()
    }

    func configure(player: AVPlayer, isVideo: Bool, episodeTitle: String) {
        self.isVideo = isVideo
        self.episodeTitle = episodeTitle
        guard isViewLoaded else {
            self.player = player
            return
        }
        if self.player !== player {
            self.player = player
            playerVC.player = player
            player.play()
        }
    }

    @objc private func enterFullscreenTapped() {
        OrientationManager.shared.supportedOrientations = [.portrait, .landscape]
        let fullscreenVC = FullscreenLandscapePlayerViewController()
        fullscreenVC.player = player
        fullscreenVC.modalPresentationStyle = .fullScreen
        fullscreenVC.modalTransitionStyle = .crossDissolve
        present(fullscreenVC, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
    }
}

/// 横屏全屏播放器，仅支持横屏
final class FullscreenLandscapePlayerViewController: UIViewController {
    var player: AVPlayer!

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true

        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerVC.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        OrientationManager.shared.supportedOrientations = .landscape
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        OrientationManager.shared.supportedOrientations = .portrait
    }
}
#endif
