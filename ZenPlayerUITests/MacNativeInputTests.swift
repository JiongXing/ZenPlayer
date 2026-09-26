import XCTest

/// 显式 --native-input-probe 才会选择此诊断，不作为产品阶段通过数。
@MainActor
final class StageUITests: XCTestCase {
    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    func testNativeTextFieldUnicodeEventSynthesis() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--stage-seed", "--stage-primary-window", "--stage-category-failure", "--stage-native-input-probe"]
        app.launch()
        let field = app.textFields["nativeInputProbeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.click()
        field.typeText("12")
        XCTAssertEqual(field.value as? String, "12")
        field.typeKey("a", modifierFlags: .command)
        let before = XCTAttachment(string: field.debugDescription)
        before.name = "native-input-focused-before-unicode"
        before.lifetime = .keepAlways
        add(before)
        field.typeText("第１２集")
        let after = XCTAttachment(string: field.debugDescription)
        after.name = "native-input-after-unicode"
        after.lifetime = .keepAlways
        add(after)
        XCTAssertEqual(field.value as? String, "第１２集")
    }
}
