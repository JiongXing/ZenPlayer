//
//  CategoryRowView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/12.
//

import SwiftUI
import Kingfisher

/// 一级类目行视图 - 单列布局，窄屏时封面上方/宽屏时封面在左
struct CategoryRowView: View {
    let category: CategoryItem

    @State private var isHovered = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
            #else
            regularLayout
            #endif
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
#if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
#endif
    }

    // MARK: - 窄屏布局（iPhone）

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            KFImage(URL(string: category.coverUrl))
                .placeholder {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .onFailureImage(PlatformImage.systemImage("photo"))
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(category.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(category.desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                        .font(.caption)
                    Text(L10n.text(.contentBrowseSeries))
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 宽屏布局（iPad / macOS）

    private var regularLayout: some View {
        HStack(spacing: 16) {
            KFImage(URL(string: category.coverUrl))
                .placeholder {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .onFailureImage(PlatformImage.systemImage("photo"))
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 90)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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

                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                        .font(.caption)
                    Text(L10n.text(.contentBrowseSeries))
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 154)
    }
}
