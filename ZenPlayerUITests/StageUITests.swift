import XCTest

/// 通过独立 bundle 运行实际 App；本地播放样本由 seed_fixture.py 写入隔离容器。
@MainActor
final class StageUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeResumeMiniPlayerPauseNavigationAndColdRestart() throws {
        let app = XCUIApplication()
        app.launch()
        let resume = app.buttons["繼續收聽"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["暫停"].firstMatch.exists)
        resume.tap()
        XCTAssertTrue(app.buttons["暫停"].firstMatch.waitForExistence(timeout: 15))
        let mini = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "UI 靜音驗證, 1, ")).firstMatch
        XCTAssertTrue(mini.exists)
        XCTAssertLessThanOrEqual(mini.frame.maxY, app.tabBars.firstMatch.frame.minY)
        XCTAssertGreaterThanOrEqual(mini.frame.height, 44)
        capture(app, name: "home-mini-above-tab")

        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.tabBars.buttons["我的"].isSelected)
        XCTAssertTrue(app.buttons["暫停"].firstMatch.exists)
        app.buttons["暫停"].firstMatch.tap()
        XCTAssertTrue(mini.label.contains("已暫停"))
        XCTAssertLessThanOrEqual(mini.frame.maxY, app.tabBars.firstMatch.frame.minY)
        capture(app, name: "my-mini-paused")
        mini.tap()
        assertPausedFullPlayer(app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["更多"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["暫停"].exists)

        // 历史／下载同集重进必须保持暂停；从详情迷你条打开控制页再返回须保留原页面。
        for feature in ["最近播放、", "下載完成、"] {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", feature)).firstMatch.tap()
            XCTAssertTrue(mini.waitForExistence(timeout: 5))
            XCTAssertTrue(mini.isHittable)
            mini.tap()
            assertPausedFullPlayer(app)
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(mini.waitForExistence(timeout: 5))
            capture(app, name: "detail-after-mini-return")
            let record = app.buttons.matching(NSPredicate(
                format: "label CONTAINS %@ AND NOT label BEGINSWITH %@",
                "UI 靜音驗證", "UI 靜音驗證, 1, "
            )).firstMatch
            XCTAssertTrue(record.waitForExistence(timeout: 5))
            XCTAssertTrue(record.isHittable)
            record.tap()
            assertPausedFullPlayer(app)
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(mini.waitForExistence(timeout: 5))
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 5))
        }

        app.buttons["更多"].tap()
        app.buttons["停止播放"].tap()
        XCTAssertFalse(app.buttons["更多"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["暫停"].exists)
        XCTAssertFalse(app.buttons["更多"].exists)
        capture(app, name: "cold-launch-resume-without-playback")
    }

    func testSearchAndSeriesNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        let category = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "淨宗學人修學")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 30))
        category.tap()
        let search = app.textFields["catalogSearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 30))
        search.tap()
        search.typeText("ZenPlayerNoMatch987654321")
        XCTAssertTrue(app.staticTexts["已載入內容中沒有符合的結果"].waitForExistence(timeout: 5))
        app.buttons["清除關鍵詞"].tap()
        XCTAssertFalse(app.staticTexts["已載入內容中沒有符合的結果"].exists)
        let course = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "編號：01-001")).firstMatch
        XCTAssertTrue(course.waitForExistence(timeout: 10))
        course.tap()
        XCTAssertTrue(app.buttons["跳至集數"].waitForExistence(timeout: 30))
        XCTAssertTrue(search.waitForExistence(timeout: 30))
        search.tap()
        search.typeText("12")
        XCTAssertTrue(app.staticTexts["找到 1 集"].waitForExistence(timeout: 5))

        enterJump("99999", app: app)
        XCTAssertTrue(app.staticTexts["找不到此集，請確認集數"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["找到 1 集"].exists)
        enterJump("0012", app: app)
        XCTAssertTrue(app.staticTexts["找到 21 集"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["第 12 集"].firstMatch.isHittable)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.buttons["暫停"].exists)
        XCTAssertFalse(app.buttons["更多"].exists)
        capture(app, name: "series-located-without-playback")
    }

    private func enterJump(_ value: String, app: XCUIApplication) {
        app.buttons["跳至集數"].tap()
        let jump = app.textFields["集數，例如 12 或第12集"]
        XCTAssertTrue(jump.waitForExistence(timeout: 5))
        jump.tap()
        if let previous = jump.value as? String, previous != jump.placeholderValue {
            jump.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        jump.typeText(value)
        app.buttons["定位"].tap()
    }

    private func assertPausedFullPlayer(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["已暫停"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["暫停"].exists)
        XCTAssertFalse(app.buttons["更多"].exists)
        capture(app, name: "paused-full-player")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
