//
//  SeriesRowView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import Kingfisher

/// 二级类目列表行视图
struct SeriesRowView: View {
    let series: SeriesItem

    @State private var isHovered = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        HStack(spacing: isCompact ? 10 : 14) {
            // 封面缩略图
            KFImage(URL(string: series.coverUrl))
                .placeholder {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .onFailureImage(PlatformImage.systemImage("photo"))
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(width: isCompact ? 72 : 100, height: isCompact ? 50 : 70)
                .clipped()

            // 文字信息
            VStack(alignment: .leading, spacing: isCompact ? 3 : 5) {
                Text(series.title)
                    .font(isCompact ? .subheadline : .headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // 详情行：作者 + 日期（窄屏用 caption）
                HStack(spacing: isCompact ? 8 : 12) {
                    if !series.author.isEmpty {
                        Label(series.author, systemImage: "person")
                            .font(isCompact ? .caption : .subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !series.date.isEmpty {
                        Label(series.date, systemImage: "calendar")
                            .font(isCompact ? .caption : .subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)

                // 底部行：编号 + 集数 + 类型标签（窄屏隐藏地点，节省空间）
                HStack(spacing: isCompact ? 8 : 12) {
                    if !isCompact, !series.address.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label(series.address.trimmingCharacters(in: .whitespaces), systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !series.num.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(L10n.string(.seriesNumberLabel, series.num))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(L10n.string(.seriesEpisodeCount, Int64(series.total)))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    typeTag
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isCompact ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isHovered)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }

    // MARK: - 类型标签

    private var typeTag: some View {
        HStack(spacing: 3) {
            Image(systemName: series.isVideo ? "video.fill" : "headphones")
                .font(.caption2)
            Text(series.isVideo ? L10n.text(.episodeVideo) : L10n.text(.episodeAudio))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(series.isVideo ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
        )
        .foregroundStyle(series.isVideo ? .blue : .orange)
    }
}
