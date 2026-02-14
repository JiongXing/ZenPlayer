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
    let index: Int
    let serverUrl: String

    /// 下载管理器（由父视图传入）
    var downloadManager: DownloadManager

    @State private var isHovered = false

    /// 是否有可用的 mp3 下载链接
    private var hasMp3: Bool {
        if let mp3Url = episode.mp3Url, !mp3Url.isEmpty { return true }
        return false
    }

    /// 是否有可用的 mp4 下载链接
    private var hasMp4: Bool {
        !episode.mp4Url.isEmpty
    }

    var body: some View {
        HStack(spacing: 14) {
            // 集数序号
            Text("\(index + 1)")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .center)

            // 封面缩略图 / 音频图标
            if episode.isVideo {
                // 视频讲集：显示封面缩略图
                KFImage(URL(string: episode.coverUrl))
                    .placeholder {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.gray.opacity(0.12))
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
                    .onFailureImage(KFCrossPlatformImage(systemSymbolName: "play.rectangle", accessibilityDescription: nil))
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .frame(width: 80, height: 50)
                    .clipped()
            } else {
                // 音频讲集：使用渐变背景 + 耳机图标
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "headphones")
                        .font(.title3)
                        .foregroundStyle(Color.orange.opacity(0.7))
                }
                .frame(width: 50, height: 50)
            }

            // 标题
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(1)

                Text("第 \(episode.episode) 集")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 时长
            Label(episode.formattedDuration, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 文件大小
            Text(episode.formattedFileSize)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .trailing)

            // 下载操作区域：音频下载 + 视频下载
            HStack(spacing: 8) {
                if hasMp3 {
                    downloadButton(type: .mp3)
                }
                if hasMp4 {
                    downloadButton(type: .mp4)
                }
            }
            .frame(minWidth: 80)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
            // 下载中：显示进度环 + 百分比 + 停止按钮
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
                    downloadManager.cancelDownload(episodeId: episode.id, type: type)
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("停止\(label)下载")
            }
            .animation(.easeInOut(duration: 0.3), value: progress)

        case .completed:
            // 完成状态：显示绿色对勾
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
            .help("\(label)下载完成")

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
