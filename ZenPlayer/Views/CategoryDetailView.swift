//
//  CategoryDetailView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI

/// 二级类目页面 - 展示某个一级类目下的讲演列表
struct CategoryDetailView: View {
    let category: CategoryItem

    @State private var viewModel = CategoryDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.seriesList.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.seriesList.isEmpty {
                errorView(message: error)
            } else {
                contentView
            }
        }
        .navigationTitle(category.title)
        .animation(.easeInOut(duration: 0.3), value: viewModel.seriesList.isEmpty)
        .task {
            if viewModel.seriesList.isEmpty {
                await viewModel.loadSeries(cateId: category.cateId)
            }
        }
    }

    // MARK: - 内容视图

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 4) {
                // 类目描述
                if !category.desc.isEmpty {
                    Text(category.desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }

                // 统计信息
                HStack {
                    Text("共 \(viewModel.seriesList.count) 个专辑")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)

                // 列表
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.seriesList) { series in
                        NavigationLink(value: series) {
                            SeriesRowView(series: series)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
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
                    await viewModel.loadSeries(cateId: category.cateId)
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
