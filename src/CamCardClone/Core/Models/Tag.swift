import Foundation

/// 名片标签。标签名唯一；删除标签时需同步从所有名片的 tags 中移除。
struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
