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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardBackground: Color {
#if os(iOS)
        Color("HomeSurface")
#elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(.systemBackground)
#endif
    }

    private var shadowColor: Color {
#if os(iOS)
        .clear
#else
        .black.opacity(isHovered ? 0.15 : 0.08)
#endif
    }

    private var shadowRadius: CGFloat {
#if os(iOS)
        0
#else
        isHovered ? 12 : 6
#endif
    }

    private var shadowYOffset: CGFloat {
#if os(iOS)
        0
#else
        isHovered ? 6 : 3
#endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面图片
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))

                KFImage(URL(string: category.coverUrl))
                    .placeholder {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    .onFailureImage(PlatformImage.systemImage("photo"))
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()
            .accessibilityHidden(true)

            // 文字信息
            VStack(alignment: .leading, spacing: 6) {
                #if os(iOS)
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(category.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
                #else
                Text(category.desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .compositingGroup()
        .accessibilityElement(children: .combine)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowYOffset
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }
}
