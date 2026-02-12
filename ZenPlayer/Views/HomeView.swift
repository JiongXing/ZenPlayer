//
//  HomeView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 布局样式枚举
enum LayoutStyle {
    case list   // 单列列表
    case grid   // 两列网格
}

/// 首页视图 - 展示一级类目，支持网格/列表布局切换
struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var layoutStyle: LayoutStyle = .list

    private let gridColumns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.categories.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.categories.isEmpty {
                errorView(message: error)
            } else {
                contentView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.categories.isEmpty)
        .task {
            if viewModel.categories.isEmpty {
                await viewModel.loadCategories()
            }
        }
    }

    // MARK: - 内容视图

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 页面头部（含布局切换按钮）
                headerView

                // 根据布局样式显示不同布局
                switch layoutStyle {
                case .grid:
                    gridLayoutView
                case .list:
                    listLayoutView
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .animation(.easeInOut(duration: 0.35), value: layoutStyle)
    }

    // MARK: - 两列网格布局

    private var gridLayoutView: some View {
        LazyVGrid(columns: gridColumns, spacing: 20) {
            ForEach(viewModel.categories) { category in
                NavigationLink(value: category) {
                    CategoryCardView(category: category)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - 单列列表布局

    private var listLayoutView: some View {
        LazyVStack(spacing: 14) {
            ForEach(viewModel.categories) { category in
                NavigationLink(value: category) {
                    CategoryRowView(category: category)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        VStack(spacing: 12) {
            // 标题区域
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

            // 布局切换按钮
            HStack {
                Spacer()
                layoutToggleButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    // MARK: - 布局切换按钮

    private var layoutToggleButton: some View {
        HStack(spacing: 2) {
            // 列表按钮
            Button {
                layoutStyle = .list
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 30, height: 26)
                    .foregroundStyle(layoutStyle == .list ? .white : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(layoutStyle == .list ? Color.accentColor : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            // 网格按钮
            Button {
                layoutStyle = .grid
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 30, height: 26)
                    .foregroundStyle(layoutStyle == .grid ? .white : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(layoutStyle == .grid ? Color.accentColor : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
        .animation(.easeInOut(duration: 0.2), value: layoutStyle)
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在加载...")
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

            Text("加载失败")
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
                Label("重新加载", systemImage: "arrow.clockwise")
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
