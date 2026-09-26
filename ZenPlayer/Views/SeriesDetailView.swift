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
    let series: SeriesDestination
    @State private var highlightedEpisodeID: Int?
    @State private var isJumpPresented = false
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(series: SeriesItem) {
        self.series = SeriesDestination(id: series.id, title: series.title, url: series.url)
    }

    init(destination: SeriesDestination) { self.series = destination }

    @State private var viewModel = SeriesDetailViewModel()
    @Environment(PlayerViewModel.self) private var playbackSession
    @State private var downloadManager = DownloadManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

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
        .onChange(of: viewModel.queueSnapshot) { _, snapshot in
            if let snapshot { playbackSession.queueStore.cache(snapshot) }
        }
        .navigationTitle(series.title)
        .toolbar {
            Button {
                searchFocused = false
                isJumpPresented = true
            } label: {
                Text(L10n.text(.catalogJumpTitle)).frame(minWidth: 44, minHeight: 44)
            }
            .disabled(viewModel.speechDetail == nil)
        }
        .sheet(isPresented: $isJumpPresented) {
            EpisodeJumpSheet(input: $viewModel.jumpInput) { viewModel.submitJump() }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.speechDetail != nil)
        .task {
            if viewModel.speechDetail == nil {
                await viewModel.loadSpeechDetail(url: series.url, series: series)
            }
        }
    }

    // MARK: - 内容视图

    private func contentView(detail: SpeechDetailData) -> some View {
        VStack(spacing: 0) {
            searchHeader
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        // 讲集信息头部
                        headerView(detail: detail)

                        Divider()
                            .padding(.horizontal, LayoutConstants.horizontalPadding(sizeClass: sizeClass))

                        // 播放列表标题栏
                        playlistHeader(detail: detail)
                        if let target = ResumeCandidatePolicy.latestInSeries(episodes: viewModel.episodes, serverURL: detail.serverUrl,
                                                                             records: playbackSession.progressStore.records.values) {
                            Button { viewModel.locateEpisode(id: target.context.episode.id) } label: {
                                Text(L10n.text(.resumeLocate)).frame(minWidth: 44, minHeight: 44)
                            }
                        }

                        // 播放列表（缩小两侧边距，留更多空间展示标题与元信息）
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.visibleEpisodes) { episode in
                                EpisodeRowView(
                                    episode: episode,
                                    serverUrl: detail.serverUrl,
                                    seriesType: detail.type,
                                    downloadManager: downloadManager,
                                    queueSnapshot: viewModel.queueSnapshot,
                                    isListeningTarget: highlightedEpisodeID == episode.id
                                )
                                .padding(.horizontal, 6)
                                .id(episode.id)
                                .overlay {
                                    if highlightedEpisodeID == episode.id {
                                        RoundedRectangle(cornerRadius: 10).stroke(.tint, lineWidth: 2).allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .task(id: viewModel.queueSnapshot?.id) {
                    if let target = series.targetEpisodeID { viewModel.locateEpisode(id: target) }
                }
                .task(id: viewModel.location?.id) {
                    guard let location = viewModel.location else { return }
                    searchFocused = false
                    // 清除筛选后的列表先进入布局；不触发播放。
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    highlightedEpisodeID = location.episodeID
                    if reduceMotion { reader.scrollTo(location.episodeID, anchor: .center) }
                    else { withAnimation(.easeInOut) { reader.scrollTo(location.episodeID, anchor: .center) } }
                    do {
                        try await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled, viewModel.location?.id == location.id else { return }
                        highlightedEpisodeID = nil
                    } catch { /* 新定位或离页取消旧高亮计时。 */ }
                }
            }
        }
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            CatalogSearchHeader(query: $viewModel.searchQuery, prompt: .catalogEpisodePrompt,
                                resultText: L10n.string(.catalogEpisodeResults, Int64(viewModel.visibleEpisodes.count)),
                                isLimited: viewModel.isSearchLimited, isEmpty: viewModel.visibleEpisodes.isEmpty,
                                isFocused: $searchFocused)
            if let error = viewModel.jumpError {
                Label(L10n.text(error), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red).padding(.horizontal, 16)
            }
            if !viewModel.jumpCandidates.isEmpty {
                Text(L10n.text(.catalogJumpDuplicates)).font(.subheadline).padding(.horizontal, 16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.jumpCandidates) { episode in
                            Button {
                                viewModel.locateEpisode(id: episode.id)
                            } label: {
                                Text(L10n.string(.catalogJumpCandidate, episode.episode, episode.title, episode.num))
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 180)
            }
        }
    }

    // MARK: - 头部信息

    @ViewBuilder
    private func headerView(detail: SpeechDetailData) -> some View {
        let isCompact = sizeClass == .compact

        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 16) {
                    coverImage(detail: detail, fixedWidth: nil, height: 160)
                    infoBlock(detail: detail)
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    coverImage(detail: detail, fixedWidth: 180, height: 120)
                    infoBlock(detail: detail)
                }
            }
        }
        .padding(.horizontal, LayoutConstants.horizontalPadding(sizeClass: sizeClass))
        .padding(.vertical, 20)
    }

    private func coverImage(detail: SpeechDetailData, fixedWidth: CGFloat?, height: CGFloat) -> some View {
        Group {
            if let w = fixedWidth {
                KFImage(URL(string: detail.cateCoverUrl))
                    .placeholder {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.gray.opacity(0.12))
                            ProgressView()
                        }
                    }
                    .onFailureImage(PlatformImage.systemImage("photo"))
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            } else {
                KFImage(URL(string: detail.cateCoverUrl))
                    .placeholder {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.gray.opacity(0.12))
                            ProgressView()
                        }
                    }
                    .onFailureImage(PlatformImage.systemImage("photo"))
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: height)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            }
        }
    }

    private func infoBlock(detail: SpeechDetailData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.speechTitle)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(sizeClass == .compact ? 3 : 2)

            Text(detail.pathTitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)

            Spacer().frame(height: 2)

            VStack(alignment: .leading, spacing: 5) {
                infoRow(icon: "calendar", text: detail.speechDate)
                if !detail.speechAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                    infoRow(icon: "mappin.and.ellipse",
                            text: detail.speechAddress.trimmingCharacters(in: .whitespaces))
                }
            }

            Spacer().frame(height: 4)

            HStack(spacing: 10) {
                tagView(text: detail.series, color: .green)
                typeTagView(type: detail.type)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 播放列表标题栏

    private func playlistHeader(detail: SpeechDetailData) -> some View {
        HStack {
            Label(L10n.text(.seriesPlaylist), systemImage: "list.bullet")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Text(L10n.string(.seriesEpisodeCount, Int64(viewModel.episodes.count)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, LayoutConstants.horizontalPadding(sizeClass: sizeClass))
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
            Text(isVideo ? L10n.text(.episodeVideo) : L10n.text(.episodeAudio))
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
                    await viewModel.loadSpeechDetail(url: series.url, series: series)
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
