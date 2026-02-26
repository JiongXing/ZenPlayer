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
                player: player
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("降噪强度")
                    .font(.subheadline)
                    .foregroundStyle(.black)

                HStack(spacing: 8) {
                    ForEach(PlayerViewModel.DenoiseLevel.allCases, id: \.rawValue) { level in
                        Button {
                            viewModel.denoiseLevel = level
                        } label: {
                            Text(level.label)
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(viewModel.denoiseLevel == level ? .white : .black)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(viewModel.denoiseLevel == level ? Color.black : Color.black.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerVC.didMove(toParent: self)

        player.play()
    }

    func configure(player: AVPlayer) {
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
    }
}
#endif
