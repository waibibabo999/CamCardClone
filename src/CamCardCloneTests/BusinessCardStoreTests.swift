import XCTest
@testable import CamCardClone

@MainActor
final class BusinessCardStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: BusinessCardStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BusinessCardStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = BusinessCardStore(fileURL: tempDir.appendingPathComponent("businesscards.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeCard(name: String = "张伟", company: String = "上海远景科技有限公司") -> BusinessCard {
        let uuid = UUID().uuidString
        return BusinessCard(
            originalImageFileName: "\(uuid)_original.jpg",
            processedImageFileName: "\(uuid)_processed.jpg",
            name: name,
            company: company
        )
    }

    func testAddIncrementsCardCount() throws {
        try store.add(makeCard())
        XCTAssertEqual(store.cards.count, 1)
    }

    func testDeleteRemovesCard() throws {
        let card = makeCard()
        try store.add(card)
        try store.delete(id: card.id)
        XCTAssertTrue(store.cards.isEmpty)
    }

    func testSearchMatchesNameAndCompany() throws {
        try store.add(makeCard(name: "李静怡", company: "北京华信医疗科技有限公司"))
        try store.add(makeCard(name: "王浩然", company: "广州南方贸易有限公司"))

        XCTAssertEqual(store.search(keyword: "华信").count, 1)
        XCTAssertEqual(store.search(keyword: "王浩然").count, 1)
        XCTAssertEqual(store.search(keyword: "不存在的名字").count, 0)
    }

    func testPersistenceAcrossStoreInstances() throws {
        let url = tempDir.appendingPathComponent("persistence.json")
        let first = BusinessCardStore(fileURL: url)
        try first.add(makeCard(name: "陈美玲"))

        let second = BusinessCardStore(fileURL: url)
        XCTAssertEqual(second.cards.count, 1)
        XCTAssertEqual(second.cards.first?.name, "陈美玲")
    }

    func testAddTagAndFilter() throws {
        let card = makeCard()
        try store.add(card)
        try store.addTag("合作伙伴")

        var tagged = card
        tagged.tags = ["合作伙伴"]
        try store.update(tagged)

        XCTAssertEqual(store.filter(tag: "合作伙伴").count, 1)
    }

    func testDeleteTagRemovesFromCards() throws {
        var card = makeCard()
        card.tags = ["合作伙伴"]
        try store.add(card)
        try store.deleteTag("合作伙伴")

        XCTAssertTrue(store.tags.isEmpty)
        XCTAssertFalse(store.cards[0].tags.contains("合作伙伴"))
    }
}
