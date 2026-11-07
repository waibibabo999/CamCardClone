import Contacts
import XCTest
@testable import CamCardClone

final class ExportServiceTests: XCTestCase {
    func testVCardMapsAllContactFields() throws {
        let card = BusinessCard(
            originalImageFileName: "original.jpg",
            processedImageFileName: "processed.jpg",
            name: "张伟",
            company: "上海远景科技有限公司",
            jobTitle: "技术总监",
            mobile: "+86 138-0013-8000",
            phone: "021-6688-1234",
            fax: "021-6688-1235",
            email: "zhangwei@example.com",
            website: "www.yuntu-example.com",
            address: "上海市浦东新区世纪大道 100 号",
            additionalEmails: ["zhangwei.work@example.com"],
            additionalPhones: ["021-6688-9999"]
        )

        let data = try SystemExportService().makeVCard(for: card)
        let contacts = try CNContactVCardSerialization.contacts(with: data)
        let exported = try XCTUnwrap(contacts.first)

        XCTAssertEqual(exported.givenName, "张伟")
        XCTAssertEqual(exported.organizationName, "上海远景科技有限公司")
        XCTAssertEqual(exported.jobTitle, "技术总监")
        XCTAssertEqual(exported.phoneNumbers.count, 4)
        XCTAssertEqual(exported.emailAddresses.count, 2)
        XCTAssertEqual(exported.urlAddresses.first?.value as String?, "www.yuntu-example.com")
        XCTAssertEqual(exported.postalAddresses.first?.value.street, "上海市浦东新区世纪大道 100 号")
    }

    func testVCardRejectsEmptyCard() {
        let card = BusinessCard(
            originalImageFileName: "original.jpg",
            processedImageFileName: "processed.jpg"
        )
        XCTAssertThrowsError(try SystemExportService().makeVCard(for: card))
    }
}
