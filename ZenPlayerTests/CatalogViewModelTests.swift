import XCTest

@MainActor
final class CatalogViewModelTests: XCTestCase {
    func testCategoryFiltersLoadedFieldsKeepsSelectedSortAndRestoresOnClear() async {
        var calls = 0
        let values = [searchSeries(id: 3, title: "淨土", num: "3", date: "2023"),
                      searchSeries(id: 1, title: "無量壽經", num: "1", date: "2025"),
                      searchSeries(id: 2, title: "淨土", num: "2", date: "2024")]
        let model = CategoryDetailViewModel(loader: { _ in
            calls += 1
            return SeriesData(serverUrl: "", updateTime: 0, total: 5, rows: values)
        })
        await model.loadSeries(url: "fixture")
        XCTAssertTrue(model.isSearchLimited)
        XCTAssertEqual(model.visibleSeries.map(\.id), [1, 2, 3])
        model.searchQuery = "净土"
        XCTAssertEqual(model.visibleSeries.map(\.id), [2, 3])
        model.isAscending = false
        XCTAssertEqual(model.visibleSeries.map(\.id), [3, 2])
        model.sortField = .date
        XCTAssertEqual(model.visibleSeries.map(\.id), [2, 3])
        model.searchQuery = ""
        XCTAssertEqual(model.visibleSeries.map(\.id), [1, 2, 3])
        model.searchQuery = "missing"
        XCTAssertTrue(model.visibleSeries.isEmpty)
        XCTAssertEqual(model.seriesList.count, 3)
        XCTAssertEqual(calls, 1)
    }

    func testFirstOfflineIsLoadFailureAndRetryRebuildsCompleteCatalog() async {
        var calls = 0
        let model = CategoryDetailViewModel(loader: { _ in
            calls += 1
            if calls == 1 { throw APIError.networkError(URLError(.notConnectedToInternet)) }
            return SeriesData(serverUrl: "", updateTime: 0, total: 1, rows: [searchSeries(id: 1, title: "淨土", num: "1")])
        })
        await model.loadSeries(url: "fixture")
        XCTAssertEqual(model.errorMessage, L10n.string(.catalogNeedsConnection))
        XCTAssertTrue(model.seriesList.isEmpty)
        XCTAssertFalse(model.isLoading)
        await model.loadSeries(url: "fixture")
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isSearchLimited)
        XCTAssertEqual(model.visibleSeries.count, 1)
        XCTAssertEqual(calls, 2)
    }

    func testEpisodeFilterNeverChangesSnapshotAndLocateClearsFilterWithoutPlayback() async throws {
        let values = [searchEpisode(id: 90, number: "0"), searchEpisode(id: 7, number: "12"), searchEpisode(id: 12, number: "5")]
        let model = SeriesDetailViewModel(loader: { _ in searchDetail(values, total: 8) })
        await model.loadSpeechDetail(url: "fixture", series: searchDestination)
        let snapshot = try XCTUnwrap(model.queueSnapshot)
        XCTAssertTrue(model.isSearchLimited)
        model.searchQuery = "5"
        XCTAssertEqual(model.visibleEpisodes.map(\.id), [12])
        model.jumpInput = "第００１２集"
        model.submitJump()
        XCTAssertNil(model.jumpError)
        XCTAssertEqual(model.location?.episodeID, 7)
        XCTAssertEqual(model.searchQuery, "")
        XCTAssertEqual(model.visibleEpisodes.map(\.id), [90, 7, 12])
        XCTAssertEqual(model.queueSnapshot, snapshot)
        let oldLocation = model.location?.id
        model.searchQuery = "missing"
        model.locateEpisode(id: 7) // 同时用于历史和上次收听。
        XCTAssertEqual(model.searchQuery, "")
        XCTAssertNotEqual(model.location?.id, oldLocation)
        XCTAssertEqual(model.queueSnapshot, snapshot)
        model.jumpInput = "0"
        model.submitJump()
        XCTAssertEqual(model.location?.episodeID, 90)
    }

    func testJumpFailureAndDuplicatesNeverGuessAndCandidateChoiceClearsFilter() async {
        let values = [searchEpisode(id: 70, number: "12"), searchEpisode(id: 80, number: "0012")]
        let model = SeriesDetailViewModel(loader: { _ in searchDetail(values, total: 2) })
        await model.loadSpeechDetail(url: "fixture", series: searchDestination)
        XCTAssertFalse(model.isSearchLimited)
        for invalid in ["-1", "1.5", "oops"] {
            model.jumpInput = invalid
            model.submitJump()
            XCTAssertEqual(model.jumpError, .catalogJumpInvalid)
            XCTAssertNil(model.location)
        }
        model.jumpInput = "0"
        model.submitJump()
        XCTAssertEqual(model.jumpError, .catalogJumpNotFound)
        model.searchQuery = "absent"
        model.jumpInput = "12"
        model.submitJump()
        XCTAssertNil(model.location)
        XCTAssertNil(model.jumpError)
        XCTAssertEqual(model.jumpCandidates.map(\.id), [70, 80])
        model.locateEpisode(id: 80)
        XCTAssertEqual(model.location?.episodeID, 80)
        XCTAssertTrue(model.jumpCandidates.isEmpty)
        XCTAssertEqual(model.searchQuery, "")
        model.locateEpisode(id: 999)
        XCTAssertEqual(model.jumpError, .catalogJumpNotFound)
        XCTAssertEqual(model.location?.episodeID, 80)
    }

    func testSeriesOfflineAndRetryPreserveSearchAndUnknownTotalIsLimited() async {
        var calls = 0
        let model = SeriesDetailViewModel(loader: { _ in
            calls += 1
            if calls == 1 { throw URLError(.notConnectedToInternet) }
            return searchDetail([searchEpisode(id: 1, number: "1")], total: 0)
        })
        model.searchQuery = "无量寿经"
        await model.loadSpeechDetail(url: "fixture", series: searchDestination)
        XCTAssertEqual(model.errorMessage, L10n.string(.catalogNeedsConnection))
        XCTAssertNil(model.queueSnapshot)
        await model.loadSpeechDetail(url: "fixture", series: searchDestination)
        XCTAssertEqual(model.visibleEpisodes.count, 1)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.isSearchLimited)
        XCTAssertEqual(calls, 2)
    }
    func testCancelledCategoryLoadAllowsImmediateReentryAndCannotOverwriteNewData() async throws {
        var release: CheckedContinuation<SeriesData, Error>?
        var calls = 0
        let model = CategoryDetailViewModel(loader: { _ in
            calls += 1
            if calls == 1 { return try await withCheckedThrowingContinuation { release = $0 } }
            return SeriesData(serverUrl: "", updateTime: 0, total: 1, rows: [searchSeries(id: 2, title: "新", num: "2")])
        })
        let pending = Task { await model.loadSeries(url: "fixture") }
        try await waitFor { release != nil }
        let continuation = try XCTUnwrap(release)
        pending.cancel()
        await model.loadSeries(url: "fixture")
        XCTAssertEqual(model.visibleSeries.map(\.id), [2])
        continuation.resume(returning: SeriesData(serverUrl: "", updateTime: 0, total: 1,
                                                 rows: [searchSeries(id: 1, title: "舊", num: "1")]))
        await pending.value
        XCTAssertEqual(model.visibleSeries.map(\.id), [2])
        XCTAssertFalse(model.isLoading)
    }

    func testLateSeriesLoadCannotReplaceNewSnapshotOrSearchResults() async throws {
        var release: CheckedContinuation<SpeechDetailData, Error>?
        var calls = 0
        let model = SeriesDetailViewModel(loader: { _ in
            calls += 1
            if calls == 1 { return try await withCheckedThrowingContinuation { release = $0 } }
            return searchDetail([searchEpisode(id: 2, number: "2")], total: 1)
        })
        let pending = Task { await model.loadSpeechDetail(url: "old", series: searchDestination) }
        try await waitFor { release != nil }
        let continuation = try XCTUnwrap(release)
        await model.loadSpeechDetail(url: "new", series: SeriesDestination(id: 2, title: "新", url: "new"))
        let snapshot = model.queueSnapshot
        model.searchQuery = "2"
        continuation.resume(returning: searchDetail([searchEpisode(id: 1, number: "1")], total: 1))
        await pending.value
        XCTAssertEqual(model.visibleEpisodes.map(\.id), [2])
        XCTAssertEqual(model.queueSnapshot, snapshot)
        XCTAssertEqual(model.queueSnapshot?.seriesID, 2)
        XCTAssertFalse(model.isLoading)
    }

    private func waitFor(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition())
    }

}

let searchDestination = SeriesDestination(id: 1, title: "測試系列", url: "https://example.test/series")

func searchDetail(_ episodes: [EpisodeItem], total: Int) -> SpeechDetailData {
    SpeechDetailData(serverUrl: testContext().serverUrl, updateTime: 0, series: "", totalCount: total,
                     speechTitle: "測試", speechAuthor: "", speechAddress: "", speechDate: "", speechDesc: "", cateCoverUrl: "",
                     cateId: "1", albumNum: "", pathTitle: "", type: "mp3", rows: episodes)
}
