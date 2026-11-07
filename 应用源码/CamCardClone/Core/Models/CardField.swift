import Foundation

enum FieldKey: String, CaseIterable, Codable, Hashable {
    case name
    case company
    case jobTitle
    case mobile
    case phone
    case fax
    case email
    case website
    case address
    case department
    case postalCode
    case notes
}

enum FieldSource: String, Codable, Hashable {
    case ocr
    case user
    case empty
}

/// 字段解析与人工校正的最小单元。
/// `value` 为 nil 表示该字段在名片上不存在或无法确认；不允许把猜测值写入 value。
struct CardField: Identifiable, Codable, Hashable {
    var id: FieldKey { key }
    let key: FieldKey
    var value: String?
    var confidence: Double?
    var source: FieldSource

    init(key: FieldKey, value: String?, confidence: Double? = nil, source: FieldSource = .ocr) {
        self.key = key
        self.value = value
        self.confidence = confidence
        self.source = source
    }
}
