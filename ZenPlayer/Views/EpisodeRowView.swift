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

    /// 当前单集的下载状态
    private var downloadState: DownloadState {
        downloadManager.state(for: episode.id)
    }

    var body: some View {
        HStack(spacing: 14) {
            // 集数序号
            Text("\(index + 1)")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .center)

            // 封面缩略图
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

            // 下载操作区域
            downloadActionView
                .frame(width: 80)
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

    // MARK: - 下载操作视图

    @ViewBuilder
    private var downloadActionView: some View {
        switch downloadState {
        case .idle:
            // 空闲状态：显示下载按钮
            Button {
                downloadManager.startDownload(episode: episode)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("下载视频")

        case .downloading(let progress):
            // 下载中：显示进度环 + 百分比 + 停止按钮
            HStack(spacing: 6) {
                // 圆形进度指示器
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18, height: 18)

                // 百分比文字
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                // 停止按钮
                Button {
                    downloadManager.cancelDownload(episodeId: episode.id)
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("停止下载")
            }

        case .completed:
            // 完成状态：显示绿色对勾
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .help("下载完成")

        case .failed(let message):
            // 失败状态：显示红色感叹号，点击重试
            Button {
                downloadManager.startDownload(episode: episode)
            } label: {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("下载失败：\(message)，点击重试")
        }
    }
}
