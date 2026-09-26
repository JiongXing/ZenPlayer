import XCTest

@MainActor
final class StageUITests: XCTestCase {
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    func testHistoryDownloadEntryAndDeletionRetainsProgress() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        window.buttons["繼續收聽"].firstMatch.click()
        waitForPosition(in: window, greaterThan: 31)
        clickCenter(window.buttons["pause.fill"], in: window)
        XCTAssertTrue(wait { self.mini(in: window).label.contains("已暫停") })
        let paused = position(in: window)
        clickCenter(mini(in: window), in: window)
        assertPausedFullPlayer(window)
        capture(app, name: "mac-paused-full-player")
        goBack(window)
        XCTAssertTrue(mini(in: window).waitForExistence(timeout: 5))
        let myTab = window.descendants(matching: .tab).matching(identifier: "person").firstMatch
        clickCenter(myTab, in: window)

        for feature in ["最近播放", "下載完成"] {
            let link = window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", feature)).firstMatch
            XCTAssertTrue(link.waitForExistence(timeout: 5))
            clickCenter(link, in: window)
            XCTAssertTrue(mini(in: window).waitForExistence(timeout: 5))
            clickCenter(mini(in: window), in: window)
            assertPausedFullPlayer(window)
            goBack(window)
            let record = fixtureRecord(in: window)
            XCTAssertTrue(record.waitForExistence(timeout: 5))
            clickCenter(record, in: window)
            assertPausedFullPlayer(window)
            capture(app, name: "mac-\(feature)-same-paused-session")
            goBack(window)
            XCTAssertTrue(record.waitForExistence(timeout: 5))
            goBack(window)
        }

        clickCenter(mini(in: window), in: window)
        clickCenter(window.buttons["停止播放"], in: window)
        XCTAssertFalse(mini(in: window).exists)
        goBack(window)
        let downloads = window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "下載完成")).firstMatch
        clickCenter(downloads, in: window)
        let record = fixtureRecord(in: window)
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        // 限定窗口内的上下文菜单，避免命中菜单栏“编辑”中的同名动作。
        let delete = window.menuItems["trash"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(wait { !self.fixtureRecord(in: window).exists })
        capture(app, name: "mac-deleted-download")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        // 临时 App 启动只读核实实际文件已删／进度文件仍在，不重新播种。
        app.launchArguments = ["--stage-verify-deleted"]
        app.launch()
        let reopened = app.windows.firstMatch
        XCTAssertTrue(reopened.buttons["繼續收聽"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(position(in: reopened), paused, accuracy: 1)
        XCTAssertFalse(mini(in: reopened).exists)
        capture(app, name: "mac-progress-after-download-deletion")
        clickCenter(reopened.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: reopened)
        let history = reopened.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch
        clickCenter(history, in: reopened)
        clickCenter(fixtureRecord(in: reopened), in: reopened)
        // 本地文件已删且 .invalid 远端不可用；错误不能把已保存位置覆写为初始零。
        XCTAssertTrue(reopened.buttons["重試"].firstMatch.waitForExistence(timeout: 45))
        capture(app, name: "mac-deleted-media-reopen-failed")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        app.launch() // 仍为只读验证参数。
        XCTAssertTrue(app.windows.firstMatch.buttons["繼續收聽"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(position(in: app.windows.firstMatch), paused, accuracy: 1)
    }

    func testClosingLastWindowKeepsSessionUntilQuit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        window.buttons["繼續收聽"].firstMatch.click()
        waitForPosition(in: window, greaterThan: 31)
        let before = position(in: window)
        window.buttons["_XCUI:CloseWindow"].click()
        XCTAssertTrue(wait { app.windows.count == 0 })
        XCTAssertNotEqual(app.state, .notRunning)
        app.typeKey("n", modifierFlags: .command)
        let reopened = app.windows.firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 5))
        XCTAssertTrue(mini(in: reopened).label.contains("正在收聽"))
        waitForPosition(in: reopened, greaterThan: before + 2)
        capture(app, name: "mac-session-after-last-window-reopen")
    }

    func testSharedWindowsFocusCloseQuitAndColdResume() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed"]
        app.launch()
        let first = app.windows.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        let firstID = first.identifier
        XCTAssertEqual(position(in: first), 30)
        XCTAssertFalse(mini(in: first).exists)
        first.buttons["繼續收聽"].firstMatch.click()
        waitForPosition(in: first, greaterThan: 31)
        let originalWindow = app.windows.matching(NSPredicate(format: "identifier == %@", firstID)).firstMatch
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(wait { app.windows.count == 2 })
        let second = app.windows.matching(NSPredicate(format: "identifier != %@", firstID)).firstMatch
        XCTAssertTrue(mini(in: second).waitForExistence(timeout: 5))
        XCTAssertTrue(mini(in: second).label.contains("正在收聽"))
        capture(app, name: "mac-two-windows-playing")
        let pause = second.buttons["pause.fill"]
        XCTAssertTrue(pause.exists)
        XCTAssertTrue(second.frame.contains(pause.frame))
        // 外接屏上 XCTest 的自动 hit point 计算失败；点击实际窗口内的控件中心并核实结果。
        pause.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        XCTAssertTrue(wait { self.mini(in: originalWindow).label.contains("已暫停") })
        XCTAssertTrue(mini(in: second).label.contains("已暫停"))
        capture(app, name: "mac-two-windows-paused")
        let paused = position(in: second)
        second.buttons["_XCUI:CloseWindow"].click()
        XCTAssertTrue(wait { app.windows.count == 1 })
        XCTAssertTrue(mini(in: originalWindow).label.contains("已暫停"))
        XCTAssertEqual(position(in: originalWindow), paused, accuracy: 1)

        originalWindow.buttons["繼續收聽"].firstMatch.click()
        waitForPosition(in: originalWindow, greaterThan: paused + 2)
        let beforeHide = position(in: originalWindow)
        app.typeKey("h", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .runningBackground })
        // 隐藏期间让真实 AVPlayer 推进，再激活检查位置；不用播放意图冒充媒体进展。
        let delay = expectation(description: "hidden playback interval")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { delay.fulfill() }
        wait(for: [delay], timeout: 6)
        app.activate()
        waitForPosition(in: originalWindow, greaterThan: beforeHide + 2)
        capture(app, name: "mac-after-focus-loss")
        let beforeQuit = position(in: originalWindow)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        app.launchArguments = [] // 冷启动绝不重新播种进度。
        app.launch()
        let reopened = app.windows.firstMatch
        XCTAssertTrue(reopened.buttons["繼續收聽"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(mini(in: reopened).exists)
        XCTAssertGreaterThanOrEqual(position(in: reopened), beforeQuit)
        capture(app, name: "mac-cold-launch-saved-progress")
        reopened.buttons["繼續收聽"].firstMatch.click()
        waitForPosition(in: reopened, greaterThan: beforeQuit + 2)
    }

    private func mini(in window: XCUIElement) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mac 靜音生命週期驗證, 1, ")).firstMatch
    }

    private func fixtureRecord(in window: XCUIElement) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH %@",
                                           "Mac 靜音生命週期驗證", "Mac 靜音生命週期驗證, 1, ")).firstMatch
    }

    private func clickCenter(_ element: XCUIElement, in window: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(window.frame.contains(element.frame))
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func assertPausedFullPlayer(_ window: XCUIElement) {
        XCTAssertTrue(window.buttons["停止播放"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["已暫停"].exists)
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        XCTAssertFalse(mini(in: window).exists)
    }

    private func goBack(_ window: XCUIElement) {
        clickCenter(window.toolbars.buttons.firstMatch, in: window)
    }

    private func position(in window: XCUIElement) -> Double {
        for element in window.staticTexts.allElementsBoundByIndex {
            let text = (element.value as? String) ?? element.label
            if let range = text.range(of: #"\d+:\d+ / 3:00"#, options: .regularExpression) {
                let parts = text[range].components(separatedBy: " / ")[0].split(separator: ":")
                return (Double(parts[0]) ?? 0) * 60 + (Double(parts[1]) ?? 0)
            }
        }
        return -1
    }

    private func waitForPosition(in window: XCUIElement, greaterThan threshold: Double) {
        XCTAssertTrue(wait { self.position(in: window) > threshold }, "position=\(position(in: window)), expected > \(threshold)")
    }

    private func wait(_ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 15) == .completed
    }

    private func capture(_ app: XCUIApplication, name: String) {
        for (index, window) in app.windows.allElementsBoundByIndex.enumerated() {
            let tree = XCTAttachment(string: window.debugDescription)
            tree.name = "\(name)-window-\(index)-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
    }
}
