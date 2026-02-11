//
//  SeriesDetailView.swift
//  ZenPlayer
//
//  Created by jxing on 2026/2/11.
//

import SwiftUI
import Kingfisher

/// 讲集详情页 - 展示讲集信息和播放列表
struct SeriesDetailView: View {
    let series: SeriesItem

    @State private var viewModel = SeriesDetailViewModel()

    var body: some View {
        Group {
            if let detail = viewModel.speechDetail {
                contentView(detail: detail)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                loadingView
            }
        }
        .navigationTitle(series.title)
        .animation(.easeInOut(duration: 0.3), value: viewModel.speechDetail != nil)
        .task {
            if viewModel.speechDetail == nil {
                await viewModel.loadSpeechDetail(url: series.url)
            }
        }
    }

    // MARK: - 内容视图

    private func contentView(detail: SpeechDetailData) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // 讲集信息头部
                headerView(detail: detail)

                Divider()
                    .padding(.horizontal, 28)

                // 播放列表标题栏
                playlistHeader(detail: detail)

                // 播放列表
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.episodes.enumerated()), id: \.element.id) { index, episode in
                        EpisodeRowView(
                            episode: episode,
                            index: index,
                            serverUrl: detail.serverUrl
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - 头部信息

    private func headerView(detail: SpeechDetailData) -> some View {
        HStack(alignment: .top, spacing: 20) {
            // 封面
            KFImage(URL(string: detail.cateCoverUrl))
                .placeholder {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                        ProgressView()
                    }
                }
                .onFailureImage(KFCrossPlatformImage(systemSymbolName: "photo", accessibilityDescription: nil))
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(width: 180, height: 120)
            .clipped()
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)

            // 讲集信息
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(detail.speechTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)

                // 面包屑路径
                Text(detail.pathTitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer().frame(height: 2)

                // 详细信息
                VStack(alignment: .leading, spacing: 5) {
                    infoRow(icon: "person.fill", text: detail.speechAuthor)
                    infoRow(icon: "calendar", text: detail.speechDate)
                    if !detail.speechAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                        infoRow(icon: "mappin.and.ellipse",
                                text: detail.speechAddress.trimmingCharacters(in: .whitespaces))
                    }
                }

                Spacer().frame(height: 4)

                // 标签行
                HStack(spacing: 10) {
                    // 集数标签
                    tagView(text: detail.series, color: .green)

                    // 类型标签
                    typeTagView(type: detail.type)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    // MARK: - 播放列表标题栏

    private func playlistHeader(detail: SpeechDetailData) -> some View {
        HStack {
            Label("播放列表", systemImage: "list.bullet")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Text("共 \(viewModel.episodes.count) 集")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }

    // MARK: - 辅助视图

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func tagView(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
            .foregroundStyle(color)
    }

    private func typeTagView(type: String) -> some View {
        let isVideo = type == "mp4"
        return HStack(spacing: 3) {
            Image(systemName: isVideo ? "video.fill" : "headphones")
                .font(.caption2)
            Text(isVideo ? "视频" : "音频")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(isVideo ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
        )
        .foregroundStyle(isVideo ? .blue : .orange)
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
                    await viewModel.loadSpeechDetail(url: series.url)
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
