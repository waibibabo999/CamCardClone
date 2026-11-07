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
        attachScreenshot(named: "home-empty")
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
        let closeButton = app.buttons["closeScanButton"]
        let importButton = app.buttons["从相册导入"]
        if !importButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(closeButton.waitForExistence(timeout: 8))
        }
        XCTAssertTrue(app.staticTexts["单张拍摄"].exists || app.buttons["从相册导入"].exists)
        attachScreenshot(named: "camera-capture")
    }

    func testT05ImportAutomaticallyAdvancesToEditableCard() throws {
        let app = launchFreshApp()
        app.buttons["scanButton"].tap()

        let alertDismiss = app.alerts.buttons["好"]
        if alertDismiss.waitForExistence(timeout: 3) {
            alertDismiss.tap()
        }

        let importButton = app.buttons["从相册导入"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 8))
        importButton.tap()

        let photos = app.images.matching(identifier: "PXGGridLayout-Info")
        guard photos.firstMatch.waitForExistence(timeout: 8) else {
            throw XCTSkip("The simulator photo library has not been seeded with the OCR fixture")
        }
        let testCardPhoto = photos.matching(
            NSPredicate(format: "label CONTAINS %@", "10月18日")
        ).firstMatch
        guard testCardPhoto.waitForExistence(timeout: 3) else {
            throw XCTSkip("Could not locate the seeded zh_02 OCR fixture in Photos")
        }
        testCardPhoto.tap()

        let processedPreview = app.descendants(matching: .any)["processedCardPreview"]
        XCTAssertTrue(processedPreview.waitForExistence(timeout: 30))
        let nameField = app.textFields["姓名"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30))
        XCTAssertEqual(nameField.value as? String, "李静怡")
        XCTAssertEqual(app.textFields["公司"].value as? String, "北京华信医疗科技有限公司")
        XCTAssertEqual(app.textFields["职位"].value as? String, "产品经理")
        XCTAssertEqual(app.textFields["手机"].value as? String, "139-0022-4567")
        XCTAssertEqual(app.textFields["邮箱"].value as? String, "lijingyi@example.com")
        attachScreenshot(named: "imported-card-editor")

        app.buttons["saveScannedCardButton"].tap()
        XCTAssertTrue(app.staticTexts["李静怡"].waitForExistence(timeout: 20))
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
