import Foundation
import CoreGraphics

@main
struct VerificationHarness {
    static var passed = 0
    static var failed = 0

    static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        if condition() {
            passed += 1
            print("PASS  \(name)")
        } else {
            failed += 1
            print("FAIL  \(name)")
        }
    }

    static func field(_ key: FieldKey, _ fields: [CardField]) -> String? {
        fields.first { $0.key == key }?.value
    }

    static func parse(_ text: String) -> ParsedFields {
        RuleBasedFieldParser().parse(ocrResult: OCRResult(rawText: text))
    }

    @MainActor
    static func main() throws {
        let chinese = parse("""
        张伟
        技术总监
        上海远景科技有限公司
        手机：+86 138-0013-8000
        邮箱：zhangwei@example.com
        地址：上海市浦东新区世纪大道 100 号 25 层
        """)
        check(field(.name, chinese.fields) == "张伟", "中文姓名")
        check(field(.company, chinese.fields) == "上海远景科技有限公司", "中文公司")
        check(field(.jobTitle, chinese.fields) == "技术总监", "中文职位")
        check(field(.mobile, chinese.fields) == "+86 138-0013-8000", "中文手机")

        let english = parse("""
        David Chen
        Technical Director
        ABC Technologies Inc.
        Mobile: +1-415-555-0142
        Email: david.chen@example.com
        Web: www.abc-tech-example.com
        """)
        check(field(.company, english.fields) == "ABC Technologies Inc.", "英文多词公司不截断")
        check(field(.jobTitle, english.fields) == "Technical Director", "英文职位")
        check(field(.website, english.fields) == "www.abc-tech-example.com", "显式网址")

        let systems = parse("""
        Thomas Wright
        Systems Architect
        Orbit Aerospace Systems
        """)
        check(field(.jobTitle, systems.fields) == "Systems Architect", "职位与公司不混淆")
        check(field(.company, systems.fields) == "Orbit Aerospace Systems", "公司整行保留")

        let bilingual = parse("""
        朱宏明 Hongming Zhu
        教授 Professor
        同济大学 Tongji University
        手机：+86 138-1234-5678
        """)
        check(field(.name, bilingual.fields) == "朱宏明 Hongming Zhu", "中英姓名")
        check(field(.company, bilingual.fields) == "同济大学 Tongji University", "中英公司")
        check(field(.website, bilingual.fields) == nil, "缺失 Website 不虚构")

        let missing = parse("""
        高静
        发行主管
        汇文图书发行有限公司
        手机：135-1234-0000
        """)
        check(field(.website, missing.fields) == nil, "无网址字段保持 nil")

        let multiple = parse("""
        罗建华
        生产部经理
        中远精密制造有限公司
        手机：136-5555-6666
        电话：0512-6677-8899
        传真：0512-6677-8800
        邮箱：luojianhua@example.com
        邮箱：jh.luo@example.com
        """)
        check(field(.mobile, multiple.fields) == "136-5555-6666", "多电话 Mobile")
        check(field(.phone, multiple.fields) == "0512-6677-8899", "多电话 Office")
        check(field(.fax, multiple.fields) == "0512-6677-8800", "多电话 Fax")
        check(multiple.additionalEmails == ["jh.luo@example.com"], "多邮箱")

        let unlabeled = parse("""
        罗建华
        生产部经理
        中远精密制造有限公司
        136-5555-6666
        0512-6677-8899
        """)
        check(field(.mobile, unlabeled.fields) == "136-5555-6666", "无标签手机")
        check(field(.phone, unlabeled.fields) == "0512-6677-8899", "无标签办公电话")

        let full = CardGeometry.fullFrameCorners
        let size = CGSize(width: 300, height: 400)
        let roundTrip = CardGeometry.viewToNormalized(
            CardGeometry.normalizedToView(full, size: size),
            size: size
        )
        check(zip(full, roundTrip).allSatisfy { abs($0.x - $1.x) < 0.0001 && abs($0.y - $1.y) < 0.0001 },
              "坐标往返")

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CamCardLogic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let json = temp.appendingPathComponent("businesscards.json")

        let store = BusinessCardStore(fileURL: json)
        let card = BusinessCard(
            originalImageFileName: "a_original.jpg",
            processedImageFileName: "a_processed.jpg",
            name: "张伟",
            company: "上海远景科技有限公司",
            notes: "会议后跟进",
            tags: ["会议"]
        )
        try store.add(card)
        try store.addTag("会议")
        check(store.cards.count == 1, "新增名片")
        check(store.search(keyword: "远景").count == 1, "按公司搜索")
        check(store.filter(tag: "会议").count == 1, "按标签筛选")

        let reloaded = BusinessCardStore(fileURL: json)
        check(reloaded.cards.first?.notes == "会议后跟进", "备注持久化")
        check(reloaded.cards.first?.tags == ["会议"], "标签持久化")
        check(reloaded.tags.map(\.name) == ["会议"], "标签库持久化")

        var edited = card
        edited.name = "张伟（已修改）"
        try store.update(edited)
        check(store.cards.first?.name == "张伟（已修改）", "编辑名片")

        try store.deleteTag("会议")
        check(store.cards.first?.tags.isEmpty == true, "删除标签同步清理名片")
        try store.delete(id: card.id)
        check(store.cards.isEmpty, "删除名片")

        let corrupt = temp.appendingPathComponent("corrupt.json")
        try Data("not-json".utf8).write(to: corrupt)
        let brokenStore = BusinessCardStore(fileURL: corrupt)
        check(brokenStore.loadError != nil, "损坏 JSON 暴露错误")

        print("\n\(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}
