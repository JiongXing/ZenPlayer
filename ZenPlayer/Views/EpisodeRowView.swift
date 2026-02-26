//
//  EpisodeRowView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import Kingfisher

/// 播放列表中的单集行视图
struct EpisodeRowView: View {
    let episode: EpisodeItem
    let serverUrl: String

    /// 系列类型："mp4" 视频 / "mp3" 音频（音频不获取封面，仅显示耳机图标）
    var seriesType: String = "mp4"

    /// 下载管理器（由父视图传入）
    var downloadManager: DownloadManager

    @State private var isHovered = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// 是否有可用的 mp3 下载链接
    private var hasMp3: Bool {
        if let mp3Url = episode.mp3Url, !mp3Url.isEmpty { return true }
        return false
    }

    /// 是否有可用的 mp4 视频下载链接（音频系列不显示视频下载，因 API 会将 mp3 路径误填到 mp4_url）
    private var hasMp4: Bool {
        !episode.mp4Url.isEmpty && seriesType != "mp3"
    }

    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationLink(value: PlaybackContext(episode: episode, serverUrl: serverUrl)) {
            Group {
                if isCompact {
                    compactBody
                } else {
                    regularBody
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, isCompact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isHovered)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("播放")
#endif
    }

    // MARK: - iPhone 紧凑布局（两行）

    private var compactBody: some View {
        HStack(alignment: .center, spacing: 12) {
            episodeThumbnail(width: 56, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("第 \(episode.episode) 集")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Label(episode.formattedDuration, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(episode.formattedFileSize)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        if hasMp3 { downloadButton(type: .mp3) }
                        if hasMp4 { downloadButton(type: .mp4) }
                    }
                }
            }
        }
    }

    // MARK: - iPad / macOS 宽屏布局（单行）

    private var regularBody: some View {
        HStack(spacing: 14) {
            episodeThumbnail(width: episode.isVideo ? 80 : 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(1)
                Text("第 \(episode.episode) 集")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Label(episode.formattedDuration, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(episode.formattedFileSize)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .trailing)

            HStack(spacing: 8) {
                if hasMp3 { downloadButton(type: .mp3) }
                if hasMp4 { downloadButton(type: .mp4) }
            }
            .frame(minWidth: 80)
        }
    }

    // MARK: - 封面缩略图

    /// 是否为音频系列（mp3 系列不获取封面，显示耳机占位符）
    private var isAudioSeries: Bool { seriesType == "mp3" }

    @ViewBuilder
    private func episodeThumbnail(width: CGFloat, height: CGFloat) -> some View {
        if episode.isVideo && !isAudioSeries {
            KFImage(URL(string: episode.coverUrl))
                .placeholder {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
                .onFailureImage(PlatformImage.systemImage("play.rectangle"))
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(width: width, height: height)
                .clipped()
        } else {
            audioPlaceholder(width: width, height: height)
        }
    }

    /// 音频占位符：不获取封面，仅显示小耳机图标
    private func audioPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        let thumbWidth = isCompact ? width : 50
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.1),
                            Color.orange.opacity(0.06),
                            Color.orange.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "headphones")
                .font(.system(size: isCompact ? 12 : 14, weight: .light))
                .foregroundStyle(Color.orange.opacity(0.55))
        }
        .frame(width: thumbWidth, height: height)
    }

    // MARK: - 单个下载按钮（根据类型和状态渲染）

    @ViewBuilder
    private func downloadButton(type: DownloadType) -> some View {
        let state = downloadManager.state(for: episode.id, type: type)
        let icon = type == .mp3 ? "headphones" : "video.fill"
        let label = type == .mp3 ? "音频" : "视频"
        let tintColor: Color = type == .mp3 ? .orange : .blue

        switch state {
        case .idle:
            // 空闲状态：显示下载按钮
            Button {
                downloadManager.startDownload(episode: episode, type: type, serverUrl: serverUrl)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.caption2)
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(tintColor.opacity(0.1))
                )
                .foregroundStyle(tintColor)
            }
            .buttonStyle(.plain)
            .help("下载\(label)")

        case .downloading(let progress):
            // 下载中：显示进度环 + 百分比 + 暂停按钮
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tintColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                Button {
                    downloadManager.pauseDownload(episodeId: episode.id, type: type)
                } label: {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("暂停\(label)下载")
            }
            .animation(.easeInOut(duration: 0.3), value: progress)

        case .paused(let progress):
            // 暂停中：显示当前进度 + 继续 + 取消
            HStack(spacing: 4) {
                Image(systemName: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                Button {
                    downloadManager.resumeDownload(episodeId: episode.id, type: type)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundStyle(tintColor)
                }
                .buttonStyle(.plain)
                .help("继续\(label)下载")

                Button {
                    downloadManager.cancelDownload(episodeId: episode.id, type: type)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("取消\(label)下载")
            }
            .animation(.easeInOut(duration: 0.3), value: progress)

        case .completed:
            // 完成状态：绿色对勾 + iOS 分享按钮
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                #if os(iOS)
                if let fileURL = downloadManager.completedFileURL(for: episode.id, type: type) {
                    ShareLink(item: fileURL, preview: SharePreview("\(episode.title)", image: Image(systemName: icon))) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                #endif
            }
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
            #if os(macOS)
            .help("\(label)下载完成")
            #endif

        case .failed(let message):
            // 失败状态：显示红色感叹号，点击重试
            Button {
                downloadManager.startDownload(episode: episode, type: type, serverUrl: serverUrl)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.caption2)
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.red.opacity(0.1))
                )
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("\(label)下载失败：\(message)，点击重试")
        }
    }
}
