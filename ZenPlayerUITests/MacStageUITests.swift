import XCTest

@MainActor
final class StageUITests: XCTestCase {
    func testPlayerPlaylistJumpAndSeriesRoundTrip() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-queue-catalog", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        clickCenter(queueMini(in: window, episode: 1), in: window)
        setNativePlayback(false, in: window)
        let playlist = window.buttons["player.playlist"]
        clickCenter(playlist, in: window)
        let first = app.buttons["player.playlist.episode.900101"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.value as? String, "目前播放的單集")
        XCTAssertTrue(app.buttons["player.playlist.episode.900102"].exists)
        XCTAssertTrue(app.buttons["player.playlist.episode.900105"].exists)
        capture(app, name: "mac-player-playlist-current")
        first.click()
        XCTAssertTrue(wait { self.nativeIsPaused(in: window) })
        XCTAssertFalse(nativeIsPlaying(in: window))
        clickCenter(playlist, in: window)
        app.buttons["player.playlist.episode.900105"].click()
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].waitForExistence(timeout: 5))
        setNativePlayback(false, in: window)
        XCTAssertFalse(window.buttons["下一集"].isEnabled)
        clickCenter(playlist, in: window)
        XCTAssertEqual(app.buttons["player.playlist.episode.900105"].value as? String, "目前播放的單集")
        app.buttons["player.playlist.series"].click()
        XCTAssertTrue(window.textFields["catalogSearchField"].waitForExistence(timeout: 10))
        XCTAssertTrue(queueMini(in: window, episode: 5).label.contains("已暫停"))
        XCTAssertTrue(queueEpisode(in: window, number: 5).exists)
        capture(app, name: "mac-player-playlist-series-detail")
        goBack(window)
        XCTAssertTrue(playlist.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].exists)
        XCTAssertTrue(nativeIsPaused(in: window))
        XCTAssertFalse(nativeIsPlaying(in: window))
        capture(app, name: "mac-player-playlist-return-paused")
    }

    func testMinimalPlayerSettingsAndNativeControls() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        clickCenter(queueMini(in: window, episode: 1), in: window)
        clickCenter(window.buttons["下一集"], in: window)
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-2"].waitForExistence(timeout: 5))
        setNativePlayback(false, in: window)
        XCTAssertFalse(window.buttons["停止播放"].exists)
        XCTAssertFalse(window.checkBoxes["player.autoAdvance"].exists)
        XCTAssertFalse(window.buttons["player.denoise.50"].exists)
        let shot = XCTAttachment(screenshot: window.screenshot())
        shot.name = "mac-minimal-player"
        shot.lifetime = .keepAlways
        add(shot)
        setNativePlayback(true, in: window)
        expandPlayerSettings(in: window)
        XCTAssertTrue(nativeIsPlaying(in: window))
        clickCenter(window.checkBoxes["player.autoAdvance"], in: window)
        XCTAssertTrue(nativeIsPlaying(in: window), "关闭连播不暂停当前播放")
        clickCenter(window.buttons["player.denoise.50"], in: window)
        clickCenter(window.buttons["player.amplification.2"], in: window)
        let disclosure = window.descendants(matching: .any).matching(identifier: "player.settings").firstMatch
        XCTAssertTrue(disclosure.label.contains("50%") && disclosure.label.contains("2x"))
        clickCenter(disclosure, in: window)
        XCTAssertTrue(nativeIsPlaying(in: window))
        setNativePlayback(false, in: window)
        expandPlayerSettings(in: window)
        XCTAssertTrue(nativeIsPaused(in: window))
        XCTAssertEqual((window.checkBoxes["player.autoAdvance"].value as? NSNumber)?.intValue, 0)
        capture(app, name: "mac-minimal-settings-persist")
        stopFullPlayer(app, in: window)
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    func testPlayerPlaylistMissingMetadataPartialListAndLiveHighlight() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed", "--stage-primary-window"]
        launch(app)
        var window = app.windows.firstMatch
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        clickCenter(mini(in: window), in: window)
        setNativePlayback(false, in: window)
        clickCenter(window.buttons["player.playlist"], in: window)
        XCTAssertTrue(app.staticTexts["暫無所屬講集資訊"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player.playlist.episode.900002"].exists)
        XCTAssertFalse(app.buttons["player.playlist.series"].exists)
        capture(app, name: "mac-playlist-missing-metadata")
        app.terminate()

        app.launchArguments = ["--stage-seed-catalog", "--stage-catalog-edge-cases", "--stage-primary-window"]
        launch(app)
        window = app.windows.firstMatch
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        let partialMini = window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mac 定位驗證-12, 12, ")).firstMatch
        clickCenter(partialMini, in: window)
        clickCenter(window.buttons["player.playlist"], in: window)
        XCTAssertTrue(app.staticTexts["僅播放已載入的 21 集"].waitForExistence(timeout: 5))
        let current = app.buttons["player.playlist.episode.900212"]
        XCTAssertTrue(current.isHittable, "长列表首次展开应定位当前第 12 集")
        XCTAssertEqual(current.value as? String, "目前播放的單集")
        XCTAssertTrue(app.buttons["player.playlist.series"].exists)
        capture(app, name: "mac-playlist-partial-current-visible")
        app.terminate()

        app.launchArguments = ["--stage-seed-queue", "--stage-primary-window"]
        launch(app)
        window = app.windows.firstMatch
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        clickCenter(queueMini(in: window, episode: 1), in: window)
        expandPlayerSettings(in: window)
        XCTAssertEqual((window.checkBoxes["player.autoAdvance"].value as? NSNumber)?.intValue, 1)
        clickCenter(window.buttons["player.playlist"], in: window)
        let second = app.buttons["player.playlist.episode.900102"]
        let advanced = wait { second.value as? String == "目前播放的單集" }
        capture(app, name: "mac-playlist-natural-advance")
        XCTAssertTrue(advanced)
    }

    func testThirtyActualPlaysPreserveFirstProgressAfterRestart() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let arguments = ["--stage-resume-case", "thirty-plays", "--stage-resume-run", UUID().uuidString,
                         "--stage-primary-window"]
        app.launchArguments = arguments
        launch(app)
        var window = thirtyWindowAfterLaunch(app)
        openThirtySeries(app)
        enterJump("1", app: app)
        clickCenter(thirtyRow(in: window, number: 1), in: window)
        XCTAssertTrue(wait { self.nativeIsPlaying(in: window) })
        returnFromSeriesPlayerToHome(window)
        var firstPosition = -1.0
        for number in 1...30 {
            XCTAssertTrue(window.staticTexts["Mac 三十集-\(number)"].waitForExistence(timeout: 10))
            XCTAssertTrue(wait { window.buttons["pause.fill"].exists && self.queuePosition(in: window) >= (number == 1 ? 12 : 2) })
            if number == 1 || number == 30 {
                clickCenter(window.buttons["pause.fill"], in: window)
                XCTAssertTrue(wait { self.thirtyMini(in: window, number: number).label.contains("已暫停") })
            }
            if number == 1 {
                firstPosition = queuePosition(in: window)
                XCTAssertGreaterThanOrEqual(firstPosition, 12)
                XCTAssertLessThan(firstPosition, 30)
            }
            capture(app, name: "mac-thirty-actual-play-\(number)")
            if number < 30 {
                clickCenter(thirtyMini(in: window, number: number), in: window)
                let next = window.buttons["下一集"]
                XCTAssertTrue(next.isEnabled)
                clickCenter(next, in: window)
                let advanced = window.staticTexts["Mac 三十集-\(number + 1)"].waitForExistence(timeout: 10)
                if !advanced { capture(app, name: "mac-thirty-next-failed-from-\(number)") }
                XCTAssertTrue(advanced)
                goBack(window)
            }
        }
        clickCenter(thirtyMini(in: window, number: 30), in: window)
        XCTAssertFalse(window.buttons["下一集"].isEnabled)
        stopFullPlayer(app, in: window)
        goBack(window)
        clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
        clickCenter(window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch, in: window)
        XCTAssertTrue(window.staticTexts["10"].waitForExistence(timeout: 5))
        XCTAssertFalse(thirtyRow(in: window, number: 1).exists)
        let last = thirtyRow(in: window, number: 21)
        for _ in 0..<4 {
            if last.exists && window.frame.contains(last.frame) { break }
            window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -650)
        }
        XCTAssertTrue(last.exists && window.frame.contains(last.frame))
        XCTAssertFalse(thirtyRow(in: window, number: 1).exists)
        capture(app, name: "mac-thirty-recent-only-thirty-through-twenty-one")
        goBack(window)
        clickCenter(window.descendants(matching: .tab).matching(identifier: "house").firstMatch, in: window)
        openThirtySeries(app)
        enterJump("1", app: app)
        XCTAssertEqual(listenedSeconds(in: thirtyRow(in: window, number: 1).label), firstPosition, accuracy: 1)
        capture(app, name: "mac-thirty-return-to-first-original-position")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })

        // 验证三十条均由真实播放产生、最近恰为 30…21，并保存只读进度的证据副本。
        app.launchArguments = arguments + ["--stage-verify-resume", "--stage-thirty-first-position", String(firstPosition)]
        launch(app)
        window = thirtyWindowAfterLaunch(app)
        XCTAssertTrue(window.staticTexts["Mac 三十集-30"].waitForExistence(timeout: 15))
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        openThirtySeries(app)
        enterJump("1", app: app)
        XCTAssertEqual(listenedSeconds(in: thirtyRow(in: window, number: 1).label), firstPosition, accuracy: 1)
        let selectedAt = Date()
        clickCenter(thirtyRow(in: window, number: 1), in: window)
        XCTAssertTrue(wait { self.nativeIsPlaying(in: window) })
        returnFromSeriesPlayerToHome(window)
        XCTAssertTrue(window.staticTexts["Mac 三十集-1"].waitForExistence(timeout: 5))
        let restored = queuePosition(in: window)
        XCTAssertGreaterThan(restored - Date().timeIntervalSince(selectedAt), firstPosition - 4,
                             "必须带原位置恢复，不能靠从零持续播放到阈值")
        clickCenter(window.buttons["pause.fill"], in: window)
        XCTAssertTrue(wait { self.thirtyMini(in: window, number: 1).label.contains("已暫停") })
        let resumedPosition = queuePosition(in: window)
        capture(app, name: "mac-thirty-first-resumed-after-cold-start")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })

        app.launchArguments = arguments + ["--stage-verify-resume", "--stage-thirty-resumed",
                                           "--stage-thirty-first-position", String(resumedPosition)]
        launch(app)
        window = thirtyWindowAfterLaunch(app)
        XCTAssertTrue(window.staticTexts["Mac 三十集-1"].waitForExistence(timeout: 15))
        XCTAssertEqual(queuePosition(in: window), resumedPosition, accuracy: 1)
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        capture(app, name: "mac-thirty-first-retained-other-twenty-nine-unchanged")
    }

    private func launch(_ app: XCUIApplication) {
        // 样本参数不是待打开文件；所有冷启动使用同一 AppKit 参数约定。
        for (key, value) in [("-NSTreatUnknownArgumentsAsOpen", "NO"),
                             ("-ApplePersistenceIgnoreState", "YES")]
            where !app.launchArguments.contains(key) {
            app.launchArguments += [key, value]
        }
        app.launch()
    }

    private func thirtyWindowAfterLaunch(_ app: XCUIApplication) -> XCUIElement {
        // 自定义样本参数必须按选项处理；直接断言冷启动开窗，不发送新建窗口补救动作。
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        return app.windows.firstMatch
    }

    private func openThirtySeries(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        let category = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 三十集分類")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 15))
        capture(app, name: "mac-thirty-before-category-entry")
        // 有续听卡时分类卡会落到窗口底部，先实际滚动再保留完整可见断言。
        for _ in 0..<3 {
            if window.frame.contains(category.frame) { break }
            window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -200)
        }
        capture(app, name: "mac-thirty-category-ready-for-entry")
        clickCenter(category, in: window)
        let series = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 三十集系列")).firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 10))
        clickCenter(series, in: window)
        XCTAssertTrue(window.staticTexts["找到 30 集"].waitForExistence(timeout: 10))
    }

    private func returnFromSeriesPlayerToHome(_ window: XCUIElement) {
        goBack(window)
        goBack(window)
        goBack(window)
    }

    private func thirtyRow(in window: XCUIElement, number: Int) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                           "Mac 三十集-\(number)", "第 \(number) 集")).firstMatch
    }

    private func thirtyMini(in window: XCUIElement, number: Int) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mac 三十集-\(number), \(number),")).firstMatch
    }

    private func listenedSeconds(in label: String) -> Double {
        guard let range = label.range(of: #"已聽 \d+:\d+"#, options: .regularExpression) else { return -1 }
        let parts = label[range].dropFirst(3).split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return -1 }
        return minutes * 60 + seconds
    }

    func testEvictedHistoryStillLocatesAndResumesFromSeries() throws {
        try verifyEvictedHistory(resumeFromDownload: false)
    }

    func testEvictedHistoryResumesFromDownload() throws {
        try verifyEvictedHistory(resumeFromDownload: true)
    }

    private func verifyEvictedHistory(resumeFromDownload: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let arguments = ["--stage-resume-case", "long-history", "--stage-resume-run", UUID().uuidString,
                         "--stage-primary-window"]
        app.launchArguments = arguments
        launch(app)
        var window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 新近歷史-12"].waitForExistence(timeout: 15))
        clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
        clickCenter(window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch, in: window)
        XCTAssertTrue(window.staticTexts["10"].waitForExistence(timeout: 5))
        let oldRows = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 長期保留-"))
        XCTAssertEqual(oldRows.count, 0)
        let lastRecent = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 新近歷史-3")).firstMatch
        for _ in 0..<4 {
            if lastRecent.exists && window.frame.contains(lastRecent.frame) { break }
            window.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -650)
        }
        capture(app, name: "mac-long-history-recent-ten-excludes-old-series")
        XCTAssertTrue(lastRecent.exists && window.frame.contains(lastRecent.frame))
        XCTAssertEqual(oldRows.count, 0)
        goBack(window)
        clickCenter(window.descendants(matching: .tab).matching(identifier: "house").firstMatch, in: window)
        openLongHistorySeries(app)
        let search = window.textFields["catalogSearchField"]
        replaceText(search, with: "18", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        XCTAssertTrue(longHistoryRow(in: window, number: 18).label.contains("已聽完"))
        replaceText(search, with: "21", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        XCTAssertFalse(longHistoryRow(in: window, number: 12).exists)
        locateLongHistory(app)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })

        // 同一目录只读核验所有 14 条原始字节；定位不能把旧记录抬回最近十条。
        app.launchArguments = arguments + ["--stage-verify-resume"]
        launch(app)
        window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 新近歷史-12"].waitForExistence(timeout: 15))
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        if resumeFromDownload {
            clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
            clickCenter(window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "下載完成")).firstMatch, in: window)
            let download = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 長期保留-12")).firstMatch
            XCTAssertTrue(download.waitForExistence(timeout: 5))
            clickCenter(download, in: window)
        } else {
            openLongHistorySeries(app)
            locateLongHistory(app)
            clickCenter(longHistoryRow(in: window, number: 12), in: window)
        }
        XCTAssertTrue(wait { self.nativeIsPlaying(in: window) })
        goBack(window)
        if resumeFromDownload {
            goBack(window)
            clickCenter(window.descendants(matching: .tab).matching(identifier: "house").firstMatch, in: window)
        } else {
            goBack(window)
            goBack(window)
        }
        XCTAssertTrue(window.staticTexts["Mac 長期保留-12"].waitForExistence(timeout: 5))
        capture(app, name: "mac-long-history-active-home-before-position-check")
        XCTAssertTrue(wait { self.queuePosition(in: window) >= 44 })
        clickCenter(window.buttons["pause.fill"], in: window)
        let paused = queuePosition(in: window)
        XCTAssertGreaterThanOrEqual(paused, 44)
        XCTAssertLessThan(paused, 65, "必须恢复 42 秒附近，不能从零播放到阈值或错误跳尾")
        capture(app, name: "mac-long-history-\(resumeFromDownload ? "download" : "series")-resumed-old-position")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })

        // 实际收听才允许更新目标；其余 13 条逐字节不变，长期记录仍为 14 条。
        app.launchArguments = arguments + ["--stage-verify-resume", "--stage-verify-long-history-played"]
        launch(app)
        window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 長期保留-12"].waitForExistence(timeout: 15))
        XCTAssertEqual(queuePosition(in: window), paused, accuracy: 1)
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        capture(app, name: "mac-long-history-cold-updated-target-other-thirteen-unchanged")
    }

    private func openLongHistorySeries(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        capture(app, name: "mac-long-history-before-category-entry")
        let category = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 長歷史分類")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 10))
        clickCenter(category, in: window)
        let series = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 長期保留系列")).firstMatch
        XCTAssertTrue(series.waitForExistence(timeout: 10))
        clickCenter(series, in: window)
        XCTAssertTrue(window.staticTexts["找到 21 集"].waitForExistence(timeout: 10))
    }

    private func locateLongHistory(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        clickCenter(window.buttons["定位上次收聽"], in: window)
        XCTAssertEqual(window.textFields["catalogSearchField"].value as? String, "")
        let old = longHistoryRow(in: window, number: 12)
        XCTAssertTrue(wait { old.exists && !old.frame.isEmpty && window.frame.contains(old.frame) })
        XCTAssertTrue(old.label.contains("已聽 0:42"))
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        XCTAssertFalse(window.buttons["play.fill"].exists)
        capture(app, name: "mac-long-history-locate-old-twelve-without-playback")
    }

    private func longHistoryRow(in window: XCUIElement, number: Int) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                           "Mac 長期保留-\(number)", "第 \(number) 集")).firstMatch
    }

    func testEmptyHistoryHidesResumeCard() throws {
        try verifyHomeResumeCase("empty")
    }

    func testCompletedImmediateNextIsNotSkipped() throws {
        // next 为正对照：同一持久化快照能被真实 HomeResumeViewModel 恢复。
        for scenario in ["next", "blocked", "fallback"] {
            try verifyHomeResumeCase(scenario)
        }
    }

    private func verifyHomeResumeCase(_ scenario: String) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let arguments = ["--stage-resume-case", scenario, "--stage-resume-run", UUID().uuidString,
                         "--stage-primary-window", "--stage-category-failure"]
        for coldRead in [false, true] {
            app.launchArguments = arguments + (coldRead ? ["--stage-verify-resume"] : [])
            launch(app)
            let window = app.windows.firstMatch
            let error = window.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "Mac 分類請求失敗驗證")).firstMatch
            XCTAssertTrue(error.waitForExistence(timeout: 15))
            if scenario == "next" {
                XCTAssertTrue(window.buttons["繼續下一集"].waitForExistence(timeout: 10))
                XCTAssertTrue(window.staticTexts["Mac 候選驗證-2"].exists)
                XCTAssertTrue(window.staticTexts["已聽 0:07 / 2:00"].exists)
            } else if scenario == "fallback" {
                XCTAssertTrue(window.buttons["繼續收聽"].waitForExistence(timeout: 10))
                XCTAssertTrue(window.staticTexts["Mac 其他未完成驗證"].exists)
                capture(app, name: "mac-resume-fallback-before-progress-assertion")
                XCTAssertTrue(window.staticTexts["已收聽 0:42 · 總時長未知"].exists, "未知时长不伪造百分比")
                XCTAssertFalse(window.buttons["繼續下一集"].exists)
            } else {
                let unexpectedCard = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    window.staticTexts["繼續收聽"].exists || window.buttons["繼續收聽"].exists
                        || window.buttons["繼續下一集"].exists
                }, object: nil)
                unexpectedCard.isInverted = true
                XCTAssertEqual(XCTWaiter.wait(for: [unexpectedCard], timeout: 2), .completed,
                               "首页就绪后的观察窗口内应持续隐藏卡片")
                XCTAssertFalse(window.staticTexts["繼續收聽"].exists)
                XCTAssertFalse(window.buttons["繼續收聽"].exists)
                XCTAssertFalse(window.buttons["繼續下一集"].exists)
            }
            XCTAssertFalse(window.staticTexts["Mac 候選驗證-3"].exists, "不能跨过已完成紧邻项推荐第三集")
            XCTAssertFalse(window.buttons["pause.fill"].exists)
            capture(app, name: "mac-resume-\(scenario)-cold-\(coldRead)")
            app.typeKey("q", modifierFlags: .command)
            XCTAssertTrue(wait { app.state == .notRunning })
        }
    }

    func testBatchSearchInputRetainsExactText() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-catalog", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 定位驗證-12"].waitForExistence(timeout: 15))
        clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
        clickCenter(window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch,
                    in: window)
        clickCenter(window.buttons["返回系列並定位此集"].firstMatch, in: window)
        let search = window.textFields["catalogSearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        for (index, query) in ["1", "ZenPlayerNoMatch987654321", "12", "MAC-CATALOG 21"].enumerated() {
            clickCenter(search, in: window)
            search.typeKey("a", modifierFlags: .command)
            capture(app, name: "mac-batch-input-\(index)-focused-before-typing")
            search.typeText(query)
            capture(app, name: "mac-batch-input-\(index)-after-typing")
            XCTAssertEqual(search.value as? String, query, "批量输入必须逐字保留，不能依靠逐键重发补齐")
            if query == "ZenPlayerNoMatch987654321" {
                XCTAssertTrue(window.staticTexts["已載入內容中沒有符合的結果"].exists)
            } else {
                // 纯数字精确项优先，其余包含匹配仍保留：1 命中 1、10…19、21。
                XCTAssertTrue(window.staticTexts[query == "1" ? "找到 12 集" : "找到 1 集"].exists)
            }
            XCTAssertFalse(window.buttons["pause.fill"].exists)
        }
    }

    func testFilteredEpisodeNaturallyAdvancesThroughFullSeries() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-queue-catalog", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-1"].waitForExistence(timeout: 15))
        clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
        clickCenter(window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch,
                    in: window)
        clickCenter(window.buttons["返回系列並定位此集"].firstMatch, in: window)
        let search = window.textFields["catalogSearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        XCTAssertTrue(window.staticTexts["找到 3 集"].exists)
        replaceText(search, with: "1", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        let first = queueEpisode(in: window, number: 1)
        XCTAssertTrue(first.exists)
        XCTAssertFalse(queueEpisode(in: window, number: 2).exists)
        XCTAssertFalse(queueEpisode(in: window, number: 5).exists)
        XCTAssertFalse(window.buttons["pause.fill"].exists, "搜索本身不开播")
        capture(app, name: "mac-queue-filter-only-first-before-play")
        clickCenter(first, in: window)
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(wait { self.nativeIsPlaying(in: window) })
        XCTAssertTrue(window.buttons["下一集"].isEnabled, "仅一个搜索结果也必须保留完整队列")
        goBack(window)
        XCTAssertEqual(search.value as? String, "1")
        XCTAssertTrue(window.staticTexts["找到 1 集"].exists)
        // 不手动切集、不 seek、不发送结束通知；等待真实 10 秒 WAV 自然结束。
        let second = queueMini(in: window, episode: 2)
        XCTAssertTrue(second.waitForExistence(timeout: 20))
        XCTAssertTrue(wait { second.label.contains("正在收聽") })
        XCTAssertFalse(queueEpisode(in: window, number: 2).exists)
        XCTAssertTrue(first.label.contains("已聽完"))
        capture(app, name: "mac-filter-still-one-natural-next-is-hidden-two")
        clickCenter(window.buttons["pause.fill"], in: window)
        XCTAssertTrue(wait { second.label.contains("已暫停") })
        clickCenter(window.buttons["清除關鍵詞"], in: window)
        XCTAssertTrue(window.staticTexts["找到 3 集"].waitForExistence(timeout: 5))
        XCTAssertTrue(second.label.contains("已暫停"), "清筛选不改变播放状态")
        XCTAssertTrue(queueEpisode(in: window, number: 2).exists)
        clickCenter(second, in: window)
        XCTAssertTrue(window.buttons["上一集"].isEnabled)
        XCTAssertTrue(window.buttons["下一集"].isEnabled)
        clickCenter(window.buttons["下一集"], in: window)
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].waitForExistence(timeout: 5))
        XCTAssertFalse(window.buttons["下一集"].isEnabled)
        capture(app, name: "mac-filtered-entry-keeps-last-episode-five")
        stopFullPlayer(app, in: window)
    }

    func testPartialCatalogAndDuplicateOrZeroEpisodeLocation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-catalog", "--stage-catalog-edge-cases", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 定位驗證-12"].waitForExistence(timeout: 15))
        clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
        clickCenter(window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch,
                    in: window)
        clickCenter(window.buttons["返回系列並定位此集"].firstMatch, in: window)
        let search = window.textFields["catalogSearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        let limited = window.staticTexts["僅搜尋已載入內容"]
        XCTAssertTrue(limited.exists)
        capture(app, name: "mac-partial-catalog-loaded-21-of-24")
        replaceText(search, with: "9999", in: window)
        XCTAssertTrue(window.staticTexts["已載入內容中沒有符合的結果"].waitForExistence(timeout: 5))
        XCTAssertTrue(limited.exists, "零结果不能隐藏已加载范围")
        clickCenter(window.buttons["清除關鍵詞"], in: window)
        XCTAssertTrue(window.staticTexts["找到 21 集"].waitForExistence(timeout: 5))
        replaceText(search, with: "21", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        enterJump("12", app: app)
        let duplicates = window.staticTexts["此集數有多個條目，請選擇要定位的內容"]
        XCTAssertTrue(duplicates.waitForExistence(timeout: 5))
        let firstCandidate = window.buttons["第 12 集 · Mac 定位驗證-12 · MAC-CATALOG"]
        let secondCandidate = window.buttons["第 12 集 · Mac 定位驗證-18 · MAC-CATALOG"]
        XCTAssertTrue(firstCandidate.exists)
        XCTAssertTrue(secondCandidate.exists)
        XCTAssertEqual(search.value as? String, "21", "重复集数须等待选择，不能自动清筛选定位第一条")
        XCTAssertTrue(window.staticTexts["找到 1 集"].exists)
        capture(app, name: "mac-duplicate-episode-waits-for-choice")
        clickCenter(secondCandidate, in: window)
        XCTAssertTrue(wait { !duplicates.exists && !firstCandidate.exists && !secondCandidate.exists })
        XCTAssertTrue(window.staticTexts["找到 21 集"].exists)
        XCTAssertEqual(search.value as? String, "")
        let selected = window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                                          "Mac 定位驗證-18", "第 12 集")).firstMatch
        XCTAssertTrue(wait { selected.exists && !selected.frame.isEmpty && window.frame.contains(selected.frame) })
        XCTAssertTrue(selected.label.contains("已聽完"))
        capture(app, name: "mac-duplicate-choice-locates-second-id")
        enterJump("0", app: app)
        let zero = window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                                      "Mac 定位驗證-1", "第 0 集")).firstMatch
        XCTAssertTrue(wait { zero.exists && !zero.frame.isEmpty && window.frame.contains(zero.frame) })
        XCTAssertTrue(zero.label.contains("未收聽"))
        XCTAssertTrue(limited.exists)
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        XCTAssertFalse(window.buttons["play.fill"].exists)
        XCTAssertFalse(window.buttons["停止播放"].exists)
        capture(app, name: "mac-existing-episode-zero-located-without-playback")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        app.launchArguments = ["--stage-verify-catalog", "--stage-catalog-edge-cases", "--stage-primary-window"]
        launch(app)
        XCTAssertTrue(app.windows.firstMatch.staticTexts["Mac 定位驗證-12"].waitForExistence(timeout: 15))
        XCTAssertEqual(queuePosition(in: app.windows.firstMatch), 42)
    }

    func testCategoryFailureKeepsLocalResumePlayable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed", "--stage-category-failure", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        let error = window.staticTexts["网络错误：Mac 分類請求失敗驗證"]
        XCTAssertTrue(error.waitForExistence(timeout: 15), "必须实际经过注入的分类请求失败路径")
        let resume = window.buttons["繼續收聽"].firstMatch
        XCTAssertTrue(resume.exists)
        XCTAssertLessThan(resume.frame.maxY, error.frame.minY)
        XCTAssertEqual(position(in: window), 30)
        XCTAssertFalse(mini(in: window).exists)
        capture(app, name: "mac-category-failure-local-card")
        clickCenter(resume, in: window)
        waitForPosition(in: window, greaterThan: 31)
        XCTAssertTrue(mini(in: window).label.contains("正在收聽"))
        XCTAssertTrue(error.exists, "分类错误与本地播放同时存在")
        XCTAssertFalse(window.buttons["player.playlist"].exists, "首页直接续听无需打开完整页")
        capture(app, name: "mac-category-failure-local-playing")
        clickCenter(window.buttons["pause.fill"], in: window)
        XCTAssertTrue(wait { self.mini(in: window).label.contains("已暫停") })
    }

    func testHistorySeriesAndLatestLocationClearFilterWithoutPlayback() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-catalog", "--stage-primary-window"]
        launch(app)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.staticTexts["Mac 定位驗證-12"].waitForExistence(timeout: 15))
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        clickCenter(window.descendants(matching: .tab).matching(identifier: "person").firstMatch, in: window)
        let history = window.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "最近播放")).firstMatch
        clickCenter(history, in: window)
        let latest = window.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mac 定位驗證-12")).firstMatch
        XCTAssertTrue(latest.waitForExistence(timeout: 5))
        let returnToSeries = window.buttons["返回系列並定位此集"].firstMatch
        XCTAssertGreaterThanOrEqual(returnToSeries.frame.minY, latest.frame.maxY)
        clickCenter(returnToSeries, in: window)
        let search = window.textFields["catalogSearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        capture(app, name: "mac-history-series-before-location-check")
        let target = catalogEpisode(in: window, number: 12)
        XCTAssertTrue(wait { target.exists && !target.frame.isEmpty && window.frame.contains(target.frame) })
        XCTAssertTrue(target.label.contains("已聽 0:42"))
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        XCTAssertFalse(window.buttons["停止播放"].exists)
        capture(app, name: "mac-history-return-series-target-12")

        // 确认另外两种长期状态也通过真实行显示；不点播放按钮。
        replaceText(search, with: "18", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        XCTAssertTrue(catalogEpisode(in: window, number: 18).label.contains("已聽完"))
        replaceText(search, with: "21", in: window)
        XCTAssertTrue(window.staticTexts["找到 1 集"].waitForExistence(timeout: 5))
        XCTAssertTrue(catalogEpisode(in: window, number: 21).label.contains("未收聽"))
        XCTAssertFalse(target.exists)
        capture(app, name: "mac-series-filter-hides-latest-12")
        clickCenter(window.buttons["定位上次收聽"], in: window)
        XCTAssertTrue(window.staticTexts["找到 21 集"].waitForExistence(timeout: 5))
        XCTAssertEqual(search.value as? String, "")
        XCTAssertFalse(window.buttons["清除關鍵詞"].exists)
        XCTAssertTrue(wait { target.exists && !target.frame.isEmpty && window.frame.contains(target.frame) })
        XCTAssertTrue(target.label.contains("已聽 0:42"))
        XCTAssertFalse(window.buttons["pause.fill"].exists)
        XCTAssertFalse(window.buttons["play.fill"].exists)
        XCTAssertFalse(window.buttons["停止播放"].exists)
        capture(app, name: "mac-latest-location-clears-filter-without-playing")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        // 只读原始字节比对，防止导航／定位静默刷新收听时间、修订或位置。
        app.launchArguments = ["--stage-verify-catalog", "--stage-primary-window"]
        launch(app)
        XCTAssertTrue(app.windows.firstMatch.staticTexts["Mac 定位驗證-12"].waitForExistence(timeout: 15))
        XCTAssertEqual(queuePosition(in: app.windows.firstMatch), 42)
        XCTAssertFalse(app.windows.firstMatch.buttons["pause.fill"].exists)
        capture(app, name: "mac-location-cold-progress-unchanged")
    }

    func testAutoAdvanceOffOffersNextWithItsOwnProgress() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-auto-off", "--stage-primary-window"]
        launch(app)
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
        expandPlayerSettings(in: window)
        XCTAssertEqual((window.checkBoxes["player.autoAdvance"].value as? NSNumber)?.intValue, 0)
        XCTAssertTrue(window.buttons["上一集"].isEnabled)
        XCTAssertTrue(window.buttons["下一集"].isEnabled)
        capture(app, name: "mac-home-next-keeps-queue-and-preference")
        stopFullPlayer(app, in: window)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        app.launchArguments = ["--stage-verify-queue-off", "--stage-primary-window"]
        launch(app)
        XCTAssertTrue(app.windows.firstMatch.staticTexts["Mac 連播驗證-2"].waitForExistence(timeout: 15))
        XCTAssertFalse(queueMini(in: app.windows.firstMatch, episode: 2).exists)
        capture(app, name: "mac-home-next-cold-progress-preserved")
    }

    func testNaturalQueueAdvanceControlsAndColdPreference() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed-queue", "--stage-primary-window"]
        launch(app)
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
        expandPlayerSettings(in: window)
        let autoAdvance = window.checkBoxes["player.autoAdvance"]
        XCTAssertTrue(previous.isEnabled)
        XCTAssertTrue(next.isEnabled)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 1)
        expandPlayerSettings(in: window)
        clickCenter(autoAdvance, in: window)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 0)
        capture(app, name: "mac-queue-toggle-off-keeps-playing")
        XCTAssertTrue(nativeIsPlaying(in: window), "关闭连播不应立即暂停当前集")
        goBack(window)
        let before = queuePosition(in: window)
        XCTAssertGreaterThanOrEqual(before, 7)
        XCTAssertTrue(wait { self.queuePosition(in: window) > before + 1 })
        clickCenter(queueMini(in: window, episode: 2), in: window)
        clickCenter(next, in: window)
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "末集不能越界")
        expandPlayerSettings(in: window)
        clickCenter(autoAdvance, in: window)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 1)
        XCTAssertTrue(nativeIsPlaying(in: window), "必须在末集仍播放时启用连播再验证结束边界")
        XCTAssertTrue(window.staticTexts["已聽完"].waitForExistence(timeout: 25))
        XCTAssertTrue(window.staticTexts["Mac 連播驗證-5"].exists)
        XCTAssertFalse(nativeIsPlaying(in: window))
        XCTAssertFalse(next.isEnabled)
        capture(app, name: "mac-queue-last-ended-with-auto-on")
        expandPlayerSettings(in: window)
        clickCenter(autoAdvance, in: window)
        XCTAssertEqual((autoAdvance.value as? NSNumber)?.intValue, 0)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })

        // 冷启动只读核验上一集 completed、第二集有效进度、末集 completed、快照和关闭偏好。
        app.launchArguments = ["--stage-verify-queue", "--stage-primary-window"]
        launch(app)
        let reopened = app.windows.firstMatch
        XCTAssertTrue(reopened.staticTexts["Mac 連播驗證-2"].waitForExistence(timeout: 15))
        XCTAssertFalse(queueMini(in: reopened, episode: 2).exists)
        XCTAssertGreaterThanOrEqual(queuePosition(in: reopened), 7)
        capture(app, name: "mac-queue-cold-fallback-to-unfinished-2")
        clickCenter(reopened.buttons["繼續收聽"].firstMatch, in: reopened)
        let resumed = queueMini(in: reopened, episode: 2)
        XCTAssertTrue(resumed.waitForExistence(timeout: 5))
        clickCenter(resumed, in: reopened)
        expandPlayerSettings(in: reopened)
        XCTAssertEqual((reopened.checkBoxes["player.autoAdvance"].value as? NSNumber)?.intValue, 0)
        clickCenter(reopened.buttons["上一集"], in: reopened)
        XCTAssertTrue(reopened.staticTexts["Mac 連播驗證-1"].waitForExistence(timeout: 5))
        XCTAssertFalse(reopened.buttons["上一集"].isEnabled, "首集不能越界")
        XCTAssertTrue(nativeIsPlaying(in: reopened), "手动上一集应开始重听")
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
        launch(app)
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
        launch(app)
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
        stopFullPlayer(app, in: window)
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
        launch(app)
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
        launch(app) // 仍为只读验证参数。
        XCTAssertTrue(app.windows.firstMatch.buttons["繼續收聽"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(position(in: app.windows.firstMatch), paused, accuracy: 1)
    }

    func testSingleWindowCloseQuitAndColdResume() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let options = ["--stage-primary-window"]
        app.launchArguments = ["--stage-seed"] + options
        launch(app)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 15))
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertEqual(position(in: window), 30)
        XCTAssertFalse(mini(in: window).exists)
        clickCenter(window.buttons["繼續收聽"].firstMatch, in: window)
        waitForPosition(in: window, greaterThan: 31)
        // 单窗口场景不提供 Command-N 新建窗口。
        app.typeKey("n", modifierFlags: .command)
        XCTAssertEqual(app.windows.count, 1)
        clickCenter(window.buttons["pause.fill"], in: window)
        XCTAssertTrue(wait { self.mini(in: window).label.contains("已暫停") })
        let paused = position(in: window)
        clickCenter(window.buttons["_XCUI:CloseWindow"], in: window)
        XCTAssertTrue(wait { app.state == .notRunning })

        app.launchArguments = options // 冷启动绝不重新播种进度。
        launch(app)
        let reopened = app.windows.firstMatch
        XCTAssertTrue(reopened.buttons["繼續收聽"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertFalse(mini(in: reopened).exists)
        XCTAssertEqual(position(in: reopened), paused, accuracy: 1)
        clickCenter(reopened.buttons["繼續收聽"].firstMatch, in: reopened)
        waitForPosition(in: reopened, greaterThan: paused + 2)
        let beforeHide = position(in: reopened)
        app.typeKey("h", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .runningBackground })
        let delay = expectation(description: "hidden playback interval")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { delay.fulfill() }
        wait(for: [delay], timeout: 6)
        app.activate()
        waitForPosition(in: reopened, greaterThan: beforeHide + 2)
        let beforeQuit = position(in: reopened)
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(wait { app.state == .notRunning })
        launch(app)
        let finalWindow = app.windows.firstMatch
        XCTAssertTrue(finalWindow.buttons["繼續收聽"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertFalse(mini(in: finalWindow).exists)
        XCTAssertGreaterThanOrEqual(position(in: finalWindow), beforeQuit)
        capture(app, name: "mac-single-window-cold-resume")
        clickCenter(finalWindow.buttons["繼續收聽"].firstMatch, in: finalWindow)
        waitForPosition(in: finalWindow, greaterThan: beforeQuit + 2)
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

    private func nativeIsPlaying(in window: XCUIElement) -> Bool {
        let control = window.checkBoxes["播放/暫停"]
        return control.exists && (control.value as? NSNumber)?.intValue == 1
    }

    private func nativeIsPaused(in window: XCUIElement) -> Bool {
        let control = window.checkBoxes["播放/暫停"]
        return control.exists && (control.value as? NSNumber)?.intValue == 0
    }

    private func setNativePlayback(_ playing: Bool, in window: XCUIElement) {
        let control = window.checkBoxes["播放/暫停"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        if nativeIsPlaying(in: window) != playing { clickCenter(control, in: window) }
        XCTAssertTrue(wait { playing ? self.nativeIsPlaying(in: window) : self.nativeIsPaused(in: window) })
    }

    private func expandPlayerSettings(in window: XCUIElement) {
        let disclosure = window.descendants(matching: .any).matching(identifier: "player.settings").firstMatch
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        if !window.checkBoxes["player.autoAdvance"].exists {
            clickCenter(disclosure, in: window)
        }
        XCTAssertTrue(window.checkBoxes["player.autoAdvance"].waitForExistence(timeout: 5))
    }

    private func stopFullPlayer(_ app: XCUIApplication, in window: XCUIElement) {
        clickCenter(window.menuButtons["player.more"], in: window)
        app.menuItems["停止播放"].click()
        XCTAssertTrue(wait { !window.buttons["player.playlist"].exists })
    }

    private func assertPausedFullPlayer(_ window: XCUIElement) {
        XCTAssertTrue(window.buttons["player.playlist"].waitForExistence(timeout: 5))
        XCTAssertTrue(nativeIsPaused(in: window))
        XCTAssertFalse(nativeIsPlaying(in: window))
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

    private func queueEpisode(in window: XCUIElement, number: Int) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                           "Mac 連播驗證-\(number)", "第 \(number) 集")).firstMatch
    }

    private func catalogEpisode(in window: XCUIElement, number: Int) -> XCUIElement {
        window.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                                           "Mac 定位驗證-\(number)", "第 \(number) 集")).firstMatch
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
