import XCTest

@MainActor
final class StageUITests: XCTestCase {
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
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
