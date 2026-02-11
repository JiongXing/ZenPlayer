//
//  CategoryCardView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import Kingfisher

/// 一级类目卡片视图
struct CategoryCardView: View {
    let category: CategoryItem

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面图片
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
            .frame(height: 200)
            .clipped()

            // 文字信息
            VStack(alignment: .leading, spacing: 6) {
                Text(category.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(category.desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(
            color: .black.opacity(isHovered ? 0.15 : 0.08),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
