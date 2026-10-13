import Foundation
import Observation

@MainActor
@Observable
final class CardHolderViewModel {
    private let store: BusinessCardStore

    var cards: [BusinessCard] { store.cards }
    var isEmpty: Bool { store.cards.isEmpty }

    init(store: BusinessCardStore) {
        self.store = store
    }

    func delete(_ card: BusinessCard) {
        try? store.delete(id: card.id)
    }

    func matching(keyword: String) -> [BusinessCard] {
        store.search(keyword: keyword)
    }
}
