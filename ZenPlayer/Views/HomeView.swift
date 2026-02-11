//
//  HomeView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 首页视图 - 展示一级类目的两列网格
struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    private let columns = [
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
                // 页面头部
                headerView

                // 两列网格
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.categories) { category in
                        NavigationLink(value: category) {
                            CategoryCardView(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
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
