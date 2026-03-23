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
    @Environment(\.scenePhase) private var scenePhase
    @State private var shouldStopOnDisappear = true

    var body: some View {
        VStack(spacing: 14) {
            if let player = viewModel.player {
                mediaPlayerArea(player: player)
            } else if viewModel.isPreparingPlayback {
                ProgressView(L10n.text(.playerLoading))
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                ProgressView(L10n.text(.playerLoading))
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
        .task(id: context) {
            await viewModel.preparePlayback(episode: context.episode, serverUrl: context.serverUrl)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 仅在前台活跃态下页面离开才停止播放，避免 PiP 过渡阶段被误停。
            shouldStopOnDisappear = newPhase == .active
        }
        .onDisappear {
            if shouldStopOnDisappear {
                viewModel.stopPlayback()
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.text(.playerCannotPlay))
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
        .aspectRatio(viewModel.isVideo ? (4.0 / 3.0) : nil, contentMode: .fit)
        .frame(height: viewModel.isVideo ? nil : 220)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text(.playerVoiceDenoise))
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.2))

                HStack(spacing: 8) {
                    ForEach(PlayerViewModel.DenoiseLevel.allCases, id: \.rawValue) { level in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.denoiseLevel = level
                            }
                        } label: {
                            Text(level.label)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .foregroundStyle(viewModel.denoiseLevel == level ? .white : Color(red: 0.5, green: 0.4, blue: 0.3))
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(viewModel.denoiseLevel == level ? Color(red: 0.8, green: 0.6, blue: 0.4) : Color(red: 0.95, green: 0.9, blue: 0.85))
                                )
                                .shadow(color: viewModel.denoiseLevel == level ? Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .background(Color(red: 0.9, green: 0.85, blue: 0.8))

            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text(.playerVolumeBoost))
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.2))

                HStack(spacing: 8) {
                    ForEach(PlayerViewModel.supportedAmplificationOptions, id: \.self) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.amplificationMultiplier = option
                            }
                        } label: {
                            Text(PlayerViewModel.amplificationLabel(option))
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 9)
                                .foregroundStyle(viewModel.amplificationMultiplier == option ? .white : Color(red: 0.5, green: 0.4, blue: 0.3))
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(viewModel.amplificationMultiplier == option ? Color(red: 0.8, green: 0.6, blue: 0.4) : Color(red: 0.95, green: 0.9, blue: 0.85))
                                )
                                .shadow(color: viewModel.amplificationMultiplier == option ? Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.98, green: 0.96, blue: 0.94))
                .shadow(color: Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.15), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.9, green: 0.85, blue: 0.8), lineWidth: 1)
                )
        )
    }

    private var pageBackground: Color {
        Color(red: 0.92, green: 0.88, blue: 0.82).opacity(0.3)
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

    // 不在这里强制暂停，避免 App 进后台时被误判为页面离开。
}
#endif
