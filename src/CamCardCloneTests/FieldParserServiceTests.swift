import XCTest
@testable import CamCardClone

final class FieldParserServiceTests: XCTestCase {
    private let parser = RuleBasedFieldParser()

    private func parse(_ rawText: String) -> ParsedFields {
        parser.parse(ocrResult: OCRResult(rawText: rawText))
    }

    private func value(_ key: FieldKey, in fields: [CardField]) -> String? {
        fields.first { $0.key == key }?.value
    }

    func testParsesLabeledChineseCard() {
        let raw = """
        张伟
        技术总监
        上海远景科技有限公司
        手机：+86 138-0013-8000
        邮箱：zhangwei@example.com
        地址：上海市浦东新区世纪大道 100 号 25 层
        """
        let result = parse(raw)

        XCTAssertEqual(value(.name, in: result.fields), "张伟")
        XCTAssertEqual(value(.company, in: result.fields), "上海远景科技有限公司")
        XCTAssertEqual(value(.jobTitle, in: result.fields), "技术总监")
        XCTAssertEqual(value(.mobile, in: result.fields), "+86 138-0013-8000")
        XCTAssertEqual(value(.email, in: result.fields), "zhangwei@example.com")
        XCTAssertNotNil(value(.address, in: result.fields))
    }

    func testDoesNotFabricateMissingWebsite() {
        let raw = """
        高静
        发行主管
        汇文图书发行有限公司
        手机：135-1234-0000
        """
        let result = parse(raw)

        XCTAssertNil(value(.website, in: result.fields))
    }

    func testCollectsAdditionalEmails() {
        let raw = """
        罗建华
        生产部经理
        中远精密制造有限公司
        手机：136-5555-6666
        电话：0512-6677-8899
        传真：0512-6677-8800
        邮箱：luojianhua@example.com
        邮箱：jh.luo@example.com
        """
        let result = parse(raw)

        XCTAssertEqual(result.additionalEmails, ["jh.luo@example.com"])
        XCTAssertEqual(value(.phone, in: result.fields), "0512-6677-8899")
        XCTAssertEqual(value(.fax, in: result.fields), "0512-6677-8800")
        XCTAssertTrue(result.additionalPhones.isEmpty)
    }

    func testParsesEnglishCard() {
        let raw = """
        David Chen
        Technical Director
        ABC Technologies Inc.
        Mobile: +1-415-555-0142
        Email: david.chen@example.com
        Web: www.abc-tech-example.com
        """
        let result = parse(raw)

        XCTAssertEqual(value(.name, in: result.fields), "David Chen")
        XCTAssertEqual(value(.jobTitle, in: result.fields), "Technical Director")
        XCTAssertEqual(value(.email, in: result.fields), "david.chen@example.com")
        XCTAssertEqual(value(.website, in: result.fields), "www.abc-tech-example.com")
    }
}
