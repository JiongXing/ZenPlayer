import XCTest

@MainActor
final class CatalogSearchPerformanceTests: XCTestCase {
    func testLoadedThousandCoursesAndTwoThousandEpisodesQueryP95() async {
        let courses = (1...1000).map { searchSeries(id: $0, title: $0.isMultiple(of: 2) ? "淨土" : "無量壽經", num: "AB-\($0)") }
        let episodes = (1...2000).map { searchEpisode(id: $0, number: String($0), title: $0.isMultiple(of: 2) ? "淨土" : "無量壽經", num: "AB-\($0)") }
        let category = CategoryDetailViewModel(loader: { _ in SeriesData(serverUrl: "", updateTime: 0, total: courses.count, rows: courses) })
        let series = SeriesDetailViewModel(loader: { _ in searchDetail(episodes, total: episodes.count) })
        await category.loadSeries(url: "fixture")
        await series.loadSpeechDetail(url: "fixture", series: searchDestination)
        let queries = ["净土", "無量壽經", "ａｂ", "12", "不存在", "无量寿经 ab", "0012", ""]
        var categoryTimes: [Double] = [], episodeTimes: [Double] = []
        for _ in 0..<10 {
            for query in queries {
                var start = DispatchTime.now().uptimeNanoseconds
                category.searchQuery = query
                categoryTimes.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                start = DispatchTime.now().uptimeNanoseconds
                series.searchQuery = query
                episodeTimes.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            }
        }
        category.searchQuery = "净土"
        series.searchQuery = "净土"
        XCTAssertEqual(category.visibleSeries.count, 500)
        XCTAssertEqual(series.visibleEpisodes.count, 1000)
        let courseP95 = categoryTimes.sorted()[75], episodeP95 = episodeTimes.sorted()[75]
        print("SEARCH_PERF samples=80 courses=1000 episodes=2000 courseP95_ms=\(courseP95) episodeP95_ms=\(episodeP95) layer=ViewModel_no_UI")
        XCTAssertLessThan(courseP95, 200)
        XCTAssertLessThan(episodeP95, 200)
    }
}
