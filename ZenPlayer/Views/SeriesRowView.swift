//
//  SeriesRowView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 二级类目列表行视图
struct SeriesRowView: View {
    let series: SeriesItem

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // 封面缩略图
            AsyncImage(url: URL(string: series.coverUrl)) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 70)
            .clipped()

            // 文字信息
            VStack(alignment: .leading, spacing: 5) {
                // 标题行
                Text(series.title)
                    .font(.headline)
                    .lineLimit(1)

                // 详情行：作者 + 日期
                HStack(spacing: 12) {
                    if !series.author.isEmpty {
                        Label(series.author, systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !series.date.isEmpty {
                        Label(series.date, systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // 底部行：地点 + 集数 + 类型标签
                HStack(spacing: 12) {
                    if !series.address.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label(series.address.trimmingCharacters(in: .whitespaces), systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 集数
                    Text("\(series.total) 集")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // 类型标签
                    typeTag
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - 类型标签

    private var typeTag: some View {
        HStack(spacing: 3) {
            Image(systemName: series.isVideo ? "video.fill" : "headphones")
                .font(.caption2)
            Text(series.typeName)
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
