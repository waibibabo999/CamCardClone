import XCTest

final class ManagementFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-seed"]
        app.launch()
        XCTAssertTrue(app.staticTexts["张伟"].waitForExistence(timeout: 12))
        return app
    }

    func testT13DetailShowsContactInformation() {
        let app = launchSeeded()
        app.staticTexts["张伟"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["联系信息"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["上海远景科技有限公司"].exists)
        XCTAssertTrue(app.staticTexts["技术总监"].exists)
    }

    func testT14EditUpdatesName() {
        let app = launchSeeded()
        app.staticTexts["张伟"].firstMatch.tap()
        XCTAssertTrue(app.buttons["editCardButton"].waitForExistence(timeout: 8))
        app.buttons["editCardButton"].tap()

        let nameField = app.textFields["field_姓名"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        nameField.tap()
        nameField.typeText("A")
        app.buttons["saveCardButton"].tap()

        let updated = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "A")
        ).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 8))
    }

    func testT15SearchFindsCompany() {
        let app = launchSeeded()
        app.buttons["searchButton"].tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("远景")
        XCTAssertTrue(app.staticTexts["张伟"].waitForExistence(timeout: 8))
    }

    func testT16TagFilterFindsCard() {
        let app = launchSeeded()
        app.buttons["tagsButton"].tap()

        let tag = app.staticTexts["会议"]
        XCTAssertTrue(tag.waitForExistence(timeout: 8))
        tag.tap()
        XCTAssertTrue(app.staticTexts["张伟"].waitForExistence(timeout: 8))
    }

    func testT18PersistenceAcrossRelaunch() {
        let app = launchSeeded()
        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.staticTexts["张伟"].waitForExistence(timeout: 12))
    }

    func testT17DeleteCard() {
        let app = launchSeeded()
        app.staticTexts["张伟"].firstMatch.tap()
        XCTAssertTrue(app.buttons["detailMenuButton"].waitForExistence(timeout: 8))
        app.buttons["detailMenuButton"].tap()
        app.buttons["删除名片"].tap()

        let delete = app.buttons["删除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertFalse(app.staticTexts["张伟"].waitForExistence(timeout: 5))
    }
}
