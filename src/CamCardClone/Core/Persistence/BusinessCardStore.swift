import Foundation
import Observation

/// 名片与标签的统一持久化入口。
///
/// 所有写操作都走这里，View 不直接读写文件系统。
/// 元数据存 Documents/businesscards.json，采用原子写，避免崩溃损坏数据。
@MainActor
@Observable
final class BusinessCardStore {
    private(set) var cards: [BusinessCard] = []
    private(set) var tags: [Tag] = []
    private(set) var loadError: String?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private struct PersistenceContainer: Codable {
        var version: Int
        var cards: [BusinessCard]
        var tags: [Tag]
    }

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = documents.appendingPathComponent("businesscards.json")
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        do {
            try load()
        } catch {
            loadError = "读取名片数据失败：\(error.localizedDescription)"
        }
    }

    func load() throws {
        loadError = nil
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cards = []
            tags = []
            return
        }
        let data = try Data(contentsOf: fileURL)
        let container = try decoder.decode(PersistenceContainer.self, from: data)
        cards = container.cards
        tags = container.tags
    }

    func clearLoadError() {
        loadError = nil
    }

    func persist() throws {
        let container = PersistenceContainer(version: 1, cards: cards, tags: tags)
        let data = try encoder.encode(container)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    func save(_ newCards: [BusinessCard]) throws {
        cards = newCards
        try persist()
    }

    func add(_ card: BusinessCard) throws {
        cards.append(card)
        try persist()
    }

    func update(_ card: BusinessCard) throws {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else {
            throw BusinessCardStoreError.cardNotFound
        }
        var updated = card
        updated.updatedAt = Date()
        cards[index] = updated
        try persist()
    }

    func delete(id: UUID) throws {
        cards.removeAll { $0.id == id }
        try persist()
    }

    /// 按姓名、公司、职位、电话、Email、地址搜索；关键词为空时返回全部。
    func search(keyword: String) -> [BusinessCard] {
        let needle = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return cards }
        return cards.filter { card in
            var haystacks = [
                card.name, card.company, card.jobTitle,
                card.mobile, card.phone, card.fax, card.email,
                card.website, card.address, card.department, card.postalCode
            ].compactMap { $0 }
            haystacks.append(contentsOf: card.additionalPhones)
            haystacks.append(contentsOf: card.additionalEmails)
            haystacks.append(contentsOf: card.tags)
            if let notes = card.notes { haystacks.append(notes) }
            return haystacks.contains { $0.lowercased().contains(needle) }
        }
    }

    func filter(tag: String) -> [BusinessCard] {
        cards.filter { $0.tags.contains(tag) }
    }

    func addTag(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BusinessCardStoreError.emptyTag }
        guard !tags.contains(where: { $0.name == trimmed }) else { return }
        tags.append(Tag(name: trimmed))
        try persist()
    }

    func deleteTag(_ name: String) throws {
        tags.removeAll { $0.name == name }
        for index in cards.indices {
            cards[index].tags.removeAll { $0 == name }
        }
        try persist()
    }

    @MainActor
    static func resetPersistentStore() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: documents.appendingPathComponent("businesscards.json"))
        try? FileManager.default.removeItem(at: documents.appendingPathComponent("Images", isDirectory: true))
    }
}

enum BusinessCardStoreError: LocalizedError {
    case cardNotFound
    case emptyTag

    var errorDescription: String? {
        switch self {
        case .cardNotFound:
            return "找不到要更新的名片"
        case .emptyTag:
            return "标签名称不能为空"
        }
    }
}
