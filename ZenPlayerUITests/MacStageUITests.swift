import XCTest

@MainActor
final class StageUITests: XCTestCase {
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    func testAutoAdvanceOffOffersNextWithItsOwnProgress() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-auto-off", "--stage-primary-window"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-1"].waitForExistence(timeout: 15))
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        let first = queueMini(in: window, episode: 1)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(wait { first.label.contains("已聽完") })
        let continueNext = window.buttons["繼續下一集"]
        XCTAssertTrue(continueNext.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-2"].exists)
        XCTAssertEqual(queuePosition(in: window), 7, accuracy: 0.01)
        XCTAssertFalse(queueMini(in: window, episode: 2).exists)
        capture(app, name: "mac-home-next-after-auto-off-end")
        clickCenter(continueNext, in: window)
        let second = queueMini(in: window, episode: 2)
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertTrue(wait { second.label.contains("正在收聽") && self.queuePosition(in: window) >= 7 })
        clickCenter(second, in: window)
        XCTAssertEqual((window.checkBoxes["播完自動播放下一集"].value as? NSNumber)?.intValue, 0)
        XCTAssertTrue(window.buttons["上一集"].isEnabled)
        XCTAssertTrue(window.buttons["下一集"].isEnabled)
        capture(app, name: "mac-home-next-keeps-queue-and-preference")
        clickCenter(window.buttons["停止播放"], in: window)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        app.launchArguments = ["--stage-verify-queue-off", "--stage-primary-window"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.staticTexts["Mac 連播驗證-2"].waitForExistence(timeout: 15))
        XCTAssertFalse(queueMini(in: app.windows.firstMatch, episode: 2).exists)
        capture(app, name: "mac-home-next-cold-progress-preserved")
    }

    func testNaturalQueueAdvanceControlsAndColdPreference() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-primary-window"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-1"].waitForExistence(timeout: 15))
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        XCTAssertTrue(queueMini(in: window, episode: 1).waitForExistence(timeout: 5))
        // 第一段本地 WAV 自然结束；不发送结束通知、不操作 seek 或下一集。
        let second = queueMini(in: window, episode: 2)
        XCTAssertTrue(second.waitForExistence(timeout: 20))
        XCTAssertTrue(wait { second.label.contains("正在收聽") && self.queuePosition(in: window) >= 7 })
        capture(app, name: "mac-queue-natural-1-to-2")
        clickCenter(second, in: window)
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-2"].waitForExistence(timeout: 5))
        let previous = window.buttons["上一集"]
        let next = window.buttons["下一集"]
        let autoAdvance = window.checkBoxes["播完自動播放下一集"]
        XCTAssertTrue(previous.isEnabled)
        XCTAssertTrue(next.isEnabled)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 1)
        clickCenter(autoAdvance, in: window)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 0)
        capture(app, name: "mac-queue-toggle-off-keeps-playing")
        XCTAssertTrue(window.buttons["暫停"].exists, "关闭连播不应立即暂停当前集")
        goBack(window)
        let before = queuePosition(in: window)
        XCTAssertGreaterThanOrEqual(before, 7)
        XCTAssertTrue(wait { self.queuePosition(in: window) > before + 1 })
        clickCenter(queueMini(in: window, episode: 2), in: window)
        clickCenter(next, in: window)
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "末集不能越界")
        clickCenter(autoAdvance, in: window)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 1)
        XCTAssertTrue(window.buttons["暫停"].exists, "必须在末集仍播放时启用连播再验证结束边界")
        XCTAssertTrue(window.staticTexts["已聽完"].waitForExistence(timeout: 25))
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].exists)
        XCTAssertFalse(window.buttons["暫停"].exists)
        XCTAssertFalse(next.isEnabled)
        capture(app, name: "mac-queue-last-ended-with-auto-on")
        clickCenter(autoAdvance, in: window)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 0)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })

        // 冷启动只读核验上一集 completed、第二集有效进度、末集 completed、快照和关闭偏好。
        app.launchArguments = ["--stage-verify-queue", "--stage-primary-window"]
        app.launch()
        let reopened = app.windows.firstMatch
        XCTAssertTrue(reopened.staticTexts["Mac 連播驗證-2"].waitForExistence(timeout: 15))
        XCTAssertFalse(queueMini(in: reopened, episode: 2).exists)
        XCTAssertGreaterThanOrEqual(queuePosition(in: reopened), 7)
        capture(app, name: "mac-queue-cold-fallback-to-unfinished-2")
        clickCenter(reopened.buttons["繼續收聽"].firstMatch, in: reopened)
        let resumed = queueMini(in: reopened, episode: 2)
        XCTAssertTrue(resumed.waitForExistence(timeout: 5))
        clickCenter(resumed, in: reopened)
        XCTAssertEqual((reopened.checkBoxes["播完自動播放下一集"].value as? NSNumber)?.intValue, 0)
        clickCenter(reopened.buttons["上一集"], in: reopened)
        XCTAssertTrue(reopened.staticTexts["Mac 連播驗證-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(reopened.buttons["上一集"].isEnabled, "首集不能越界")
        XCTAssertTrue(reopened.buttons["暫停"].exists, "手动上一集应开始重听")
        goBack(reopened)
        XCTAssertTrue(queueMini(in: reopened, episode: 1).waitForExistence(timeout: 5))
        let replay = queuePosition(in: reopened, duration: "0:10")
        XCTAssertGreaterThanOrEqual(replay, 0)
        XCTAssertLessThan(replay, 7, "已完成集应从头重听，不恢复尾部")
        capture(app, name: "mac-queue-relisten-first-from-start")
    }

    func testCatalogSortingAndKeyboardJumpPreservePausedSession() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed", "--stage-primary-window"]
        app.launch()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        XCTAssertTrue(wait { window.frame.minX >= 0 && window.frame.minY >= 0 })
        window.buttons["繼續收聽"].firstMatch.click()
        waitForPosition(in: window, greaterThan: 31)
        clickCenter(window.buttons["pause.fill"], in: window)
        XCTAssertTrue(wait { self.mini(in: window).label.contains("已暫停") })
        let paused = position(in: window)
        let category = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "淨宗學人修學")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 30))
        clickCenter(category, in: window)
        let search = window.textFields["catalogSearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 30))
        XCTAssertTrue(window.popUpButtons.firstMatch.waitForExistence(timeout: 30))
        replaceText(search, with: "01-00", in: window)
        let ascending = courseNumbers(in: window)
        XCTAssertGreaterThan(ascending.count, 1)
        XCTAssertEqual(ascending, ascending.sorted())
        clickCenter(window.buttons["目前為升序，點擊切換為降序"], in: window)
        let descending = courseNumbers(in: window)
        XCTAssertEqual(descending, descending.sorted(by: >))
        XCTAssertNotEqual(descending.first, ascending.first)
        clickCenter(window.buttons["清除關鍵詞"], in: window)
        XCTAssertTrue(window.buttons["目前為降序，點擊切換為升序"].exists)
        replaceText(search, with: "ZenPlayerNoMatch987654321", in: window)
        XCTAssertTrue(window.staticTexts["已載入內容中沒有符合的結果"].waitForExistence(timeout: 5))
        clickCenter(window.buttons["清除關鍵詞"], in: window)
        let sort = window.popUpButtons.firstMatch
        clickCenter(sort, in: window)
        let date = app.menuItems["日期"]
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        date.click()
        XCTAssertEqual(sort.value as? String, "日期")
        capture(app, name: "mac-category-date-sort")
        replaceText(search, with: "01-001", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 門課程"].waitForExistence(timeout: 5))
        let course = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "編號：01-001")).firstMatch
        clickCenter(course, in: window)
        XCTAssertTrue(window.buttons["跳至集數"].waitForExistence(timeout: 30))
        replaceText(search, with: "21", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        capture(app, name: "mac-series-filtered-before-jump")
        XCTAssertTrue(window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "第 21 集")).firstMatch.exists)
        let target = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "第 12 集")).firstMatch
        XCTAssertFalse(target.exists)

        enterJump("99999", app: app, cancel: true)
        XCTAssertTrue(window.staticTexts["找到 1 集"].exists)
        XCTAssertFalse(window.staticTexts["找不到此集，請確認集數"].exists)
        for invalid in ["-1", "1.5"] {
            enterJump(invalid, app: app)
            XCTAssertTrue(window.staticTexts["請輸入非負整數集數，例如 12 或第12集"].waitForExistence(timeout: 5))
            XCTAssertTrue(window.staticTexts["找到 1 集"].exists)
        }
        enterJump("99999", app: app)
        XCTAssertTrue(window.staticTexts["找不到此集，請確認集數"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["找到 1 集"].exists)
        // 可通过临时 TestAction 指定 Unicode 变体，保留事件合成故障的复现入口。
        let jumpInput = try XCTUnwrap(ProcessInfo.processInfo.environment["ZENPLAYER_JUMP_INPUT"])
        XCTAssertTrue(["12", "0012", "第１２集"].contains(jumpInput))
        enterJump(jumpInput, app: app)
        XCTAssertTrue(window.staticTexts["找到 21 集"].waitForExistence(timeout: 5))
        XCTAssertFalse(window.buttons["清除關鍵詞"].exists)
        capture(app, name: "mac-series-after-jump")
        XCTAssertTrue(wait {
            guard target.exists else { return false }
            let frame = target.frame
            return !frame.isEmpty && window.frame.contains(frame)
                && frame.maxY < self.mini(in: window).frame.minY
        })
        XCTAssertTrue(mini(in: window).label.contains("已暫停"))
        capture(app, name: "mac-keyboard-jump-with-paused-session")
        goBack(window)
        goBack(window)
        XCTAssertEqual(position(in: window), paused, accuracy: 1)
    }

    func testHistoryDownloadEntryAndDeletionRetainsProgress() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed", "--stage-primary-window"]
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
        app.launchArguments = ["--stage-seed", "--stage-primary-window"]
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
        app.launchArguments = ["--stage-seed", "--stage-primary-window"]
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
        XCTAssertTrue(window.buttons["播放"].exists)
        XCTAssertFalse(window.buttons["暫停"].exists)
        XCTAssertFalse(mini(in: window).exists)
    }

    private func goBack(_ window: XCUIElement) {
        clickCenter(window.toolbars.buttons.firstMatch, in: window)
    }

    private func replaceText(_ field: XCUIElement, with text: String, in window: XCUIElement) {
        clickCenter(field, in: window)
        field.typeKey("a", modifierFlags: .command)
        // 逐键等待 XCTest idle 并核对值，不将批量合成输入的丢字符视作搜索结果。
        var expected = ""
        for character in text {
            field.typeText(String(character))
            expected.append(character)
            XCTAssertEqual(field.value as? String, expected)
        }
    }

    private func queueMini(in window: XCUIElement, episode: Int) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mac 連播驗證-\(episode), \(episode), ")).firstMatch
    }

    private func queuePosition(in window: XCUIElement, duration: String = "2:00") -> Double {
        let pattern = #"(\d+):(\d+) / "# + NSRegularExpression.escapedPattern(for: duration)
        for element in window.staticTexts.allElementsBoundByIndex {
            let text = (element.value as? String) ?? element.label
            if let range = text.range(of: pattern, options: .regularExpression) {
                let parts = text[range].components(separatedBy: " / ")[0].split(separator: ":")
                return (Double(parts[0]) ?? 0) * 60 + (Double(parts[1]) ?? 0)
            }
        }
        return -1
    }

    private func courseNumbers(in window: XCUIElement) -> [String] {
        window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "編號：01-00"))
            .allElementsBoundByIndex.compactMap { button in
                guard let range = button.label.range(of: #"01-00\d"#, options: .regularExpression) else { return nil }
                return String(button.label[range])
            }
    }

    private func enterJump(_ text: String, app: XCUIApplication, cancel: Bool = false) {
        let window = app.windows.firstMatch
        clickCenter(window.buttons["跳至集數"], in: window)
        let sheet = window.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        // 不点击输入框；typeText 要求已有键盘焦点，因此同时核实默认焦点。
        app.typeKey("a", modifierFlags: .command)
        sheet.textFields.firstMatch.typeText(text)
        XCTAssertEqual(sheet.textFields.firstMatch.value as? String, text)
        app.typeKey(cancel ? .escape : .return, modifierFlags: [])
        XCTAssertTrue(wait { !sheet.exists })
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
