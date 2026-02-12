//
//  CategoryRowView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/12.
//

import SwiftUI
import Kingfisher

/// 一级类目行视图 - 单列布局，封面在左，信息在右
struct CategoryRowView: View {
    let category: CategoryItem

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // 左侧封面图片
            KFImage(URL(string: category.coverUrl))
                .placeholder {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .onFailureImage(KFCrossPlatformImage(systemSymbolName: "photo", accessibilityDescription: nil))
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 130)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 右侧文字信息
            VStack(alignment: .leading, spacing: 8) {
                Text(category.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(category.desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                // 底部提示
                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                        .font(.caption)
                    Text("点击浏览系列")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)

            Spacer(minLength: 0)

            // 右侧箭头
            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 154)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(
            color: .black.opacity(isHovered ? 0.12 : 0.06),
            radius: isHovered ? 10 : 5,
            x: 0,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
