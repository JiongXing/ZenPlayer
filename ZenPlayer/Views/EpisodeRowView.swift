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

    @State private var isHovered = false

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
}
