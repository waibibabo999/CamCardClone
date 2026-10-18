import XCTest

final class T01_T02UITests: XCTestCase {
    private func launchFreshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()
        return app
    }

    func testT01FirstLaunchShowsEmptyCardHolder() {
        let app = launchFreshApp()
        XCTAssertTrue(app.staticTexts["30 秒快速认识 CC"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["scanButton"].exists)
    }

    func testT02ScanEntryShowsCameraAndImportChoices() {
        let app = launchFreshApp()
        app.buttons["scanButton"].tap()
        XCTAssertTrue(app.staticTexts["扫描名片"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["拍摄名片"].exists)
        XCTAssertTrue(app.buttons["从相册导入"].exists)
    }
}
