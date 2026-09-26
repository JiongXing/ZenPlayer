import XCTest

final class CatalogSearchTests: XCTestCase {
    func testFixedSimplifiedTraditionalAndWidthCaseRules() {
        for (a, b) in [("无量寿经", "無量壽經"), ("净土", "淨土"), ("  ＡＢＣ１２　", "abc12"),
                       ("發心 頭髮 後來 皇后", "发心 头发 后来 皇后")] {
            XCTAssertEqual(SearchNormalization.normalize(a), SearchNormalization.normalize(b))
        }
        XCTAssertEqual(SearchNormalization.normalize("阿彌陀經"), "阿弥陀经")
        XCTAssertEqual(SearchNormalization.normalize("𠮷"), "𠮷") // 表外字不猜测。
    }

    func testAllTokensMustMatchSomeFieldWithoutJoiningFields() {
        let index = CatalogSearchIndex(entries: [
            .init(id: 7, fields: ["無量壽經", "AB-12"]),
            .init(id: 2, fields: ["淨土", "CD-12"])
        ])
        XCTAssertEqual(index.matchingIDs(query: "　无量寿经\tａｂ　"), [7])
        XCTAssertEqual(index.matchingIDs(query: "净土 12"), [2])
        XCTAssertEqual(index.matchingIDs(query: "净土 ab"), [])
        XCTAssertEqual(index.matchingIDs(query: "經ab"), [])
        XCTAssertEqual(index.matchingIDs(query: " \n\t "), [7, 2])
    }

    func testNumericEpisodeExactFirstAndOtherMatchesKeepOriginalOrder() {
        let index = CatalogSearchIndex(entries: [
            .init(id: 1, fields: ["第12講回顧", "1"], episode: "1"),
            .init(id: 8, fields: ["別題", "0012"], episode: "0012"),
            .init(id: 3, fields: ["第12講補遺", "13"], episode: "13"),
            .init(id: 9, fields: ["另版", "12"], episode: "12")
        ])
        XCTAssertEqual(index.matchingIDs(query: "１２"), [8, 9, 1, 3])
        XCTAssertEqual(index.matchingIDs(query: "0012"), [8, 9])
        XCTAssertEqual(index.matchingIDs(query: "第12講"), [1, 3])
        XCTAssertEqual(index.matchingIDs(query: ""), [1, 8, 3, 9])
    }

    func testCategoryDoesNotTreatCourseNumberAsEpisodeAndPreservesOriginalTitle() {
        let values = [searchSeries(id: 5, title: "淨土", num: "112"), searchSeries(id: 3, title: "無量壽經", num: "12")]
        XCTAssertEqual(CatalogSearchIndex(series: values).matchingIDs(query: "12"), [5, 3])
        XCTAssertEqual(CatalogSearchIndex(series: values).matchingIDs(query: "无量寿经"), [3])
        XCTAssertEqual(values[1].title, "無量壽經")
    }

    func testJumpOnlyAcceptsNonnegativeExplicitArabicNumbers() {
        for input in ["12", "0012", "１２", "第12集", " 第００１２集 ", "第 12 集"] {
            XCTAssertEqual(EpisodeNumberParser.parse(input), 12, input)
        }
        XCTAssertEqual(EpisodeNumberParser.parse("０"), 0)
        for input in ["", "-1", "+1", "1.5", "１．５", "1e2", "第十二集", "12集", "第12", "١٢", "12 3", String(repeating: "9", count: 40)] {
            XCTAssertNil(EpisodeNumberParser.parse(input), input)
        }
        XCTAssertNil(EpisodeNumberParser.digits("第12集"))
    }

    func testJumpUsesEpisodeValueAndReturnsEveryDuplicate() {
        let values = [searchEpisode(id: 90, number: "0"), searchEpisode(id: 7, number: "12"),
                      searchEpisode(id: 42, number: "0012"), searchEpisode(id: 12, number: "5")]
        XCTAssertEqual(EpisodeNumberParser.matches(12, episodes: values).map(\.id), [7, 42])
        XCTAssertEqual(EpisodeNumberParser.matches(0, episodes: values).map(\.id), [90])
        XCTAssertTrue(EpisodeNumberParser.matches(1, episodes: values).isEmpty)
    }
}

func searchEpisode(id: Int, number: String, title: String = "無量壽經", num: String = "AB-12") -> EpisodeItem {
    let base = testContext(id: id).episode
    return EpisodeItem(id: id, num: num, title: title, episode: number, mp4Url: base.mp4Url, vodUrl: base.vodUrl,
                       mp3Url: base.mp3Url, coverUrl: "", textUrl: "", filesize: 0, duration: base.duration)
}

func searchSeries(id: Int, title: String, num: String, date: String = "2026") -> SeriesItem {
    SeriesItem(id: id, title: title, cateId: "1", num: num, date: date, author: "", address: "", total: 0,
               finish: 0, type: "mp3", typeName: "", coverUrl: "", url: "https://example.test/series/\(id)", pageUrl: "")
}
