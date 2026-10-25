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
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            if alert.buttons["允许"].exists {
                alert.buttons["允许"].tap()
                return true
            }
            if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
        app.tap()
        XCTAssertTrue(app.buttons["closeScanButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["单张拍摄"].exists || app.buttons["从相册导入"].exists)
    }
}
