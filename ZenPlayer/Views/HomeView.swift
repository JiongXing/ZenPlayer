//
//  HomeView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 首页视图 - 展示一级类目列表
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let columnSpacing: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            Group {
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.categories.isEmpty {
                    errorView(message: error)
                } else {
                    contentView(containerWidth: proxy.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.categories.isEmpty)
        .task {
            if viewModel.categories.isEmpty {
                await viewModel.loadCategories()
            }
        }
    }

    // MARK: - 内容视图

    private func contentView(containerWidth: CGFloat) -> some View {
        let horizontalPadding = LayoutConstants.horizontalPadding(sizeClass: sizeClass)
        let verticalPadding = LayoutConstants.verticalPadding(sizeClass: sizeClass)
        let availableWidth = max(containerWidth - (horizontalPadding * 2), 0)
        let columnWidth = max((availableWidth - columnSpacing) / 2, 0)

        return ScrollView {
            VStack(spacing: 24) {
                headerView

                LazyVStack(alignment: .leading, spacing: columnSpacing) {
                    ForEach(Array(categoryRows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: columnSpacing) {
                            ForEach(Array(row.enumerated()), id: \.element.id) { _, category in
                                NavigationLink(value: category) {
                                    CategoryCardView(category: category)
                                        .frame(width: columnWidth, alignment: .topLeading)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }

                            if row.count == 1 {
                                Color.clear
                                    .frame(width: columnWidth, height: 1)
                            }
                        }
                    }
                }
            }
            .frame(width: availableWidth, alignment: .topLeading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .background(homeBackground)
    }

    private var categoryRows: [[CategoryItem]] {
        stride(from: 0, to: viewModel.categories.count, by: 2).map { startIndex in
            let endIndex = min(startIndex + 2, viewModel.categories.count)
            return Array(viewModel.categories[startIndex..<endIndex])
        }
    }

    private var homeBackground: Color {
#if os(iOS)
        Color(uiColor: .systemGroupedBackground)
#elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(.systemBackground)
#endif
    }

    // MARK: - 头部视图

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(viewModel.headerTitle)
                .font(.title)
                .fontWeight(.bold)

            if !viewModel.headerSubtitle.isEmpty {
                Text(viewModel.headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(L10n.text(.homeLoading))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 错误视图

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(L10n.text(.homeLoadFailed))
                .font(.title3)
                .fontWeight(.medium)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task {
                    await viewModel.loadCategories()
                }
            } label: {
                Label(L10n.text(.homeRetry), systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
