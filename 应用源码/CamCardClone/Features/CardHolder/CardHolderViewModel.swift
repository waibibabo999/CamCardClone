import Foundation
import Observation

@MainActor
@Observable
final class CardHolderViewModel {
    private let store: BusinessCardStore

    var cards: [BusinessCard] {
        store.cards.sorted { $0.updatedAt > $1.updatedAt }
    }
    var isEmpty: Bool { store.cards.isEmpty }

    init(store: BusinessCardStore) {
        self.store = store
    }

    func delete(_ card: BusinessCard) {
        do {
            try store.delete(id: card.id)
            let imageStore = ImageStore()
            if let originalImageFileName = card.originalImageFileName {
                try? imageStore.deleteImage(fileName: originalImageFileName)
            }
            if let processedImageFileName = card.processedImageFileName {
                try? imageStore.deleteImage(fileName: processedImageFileName)
            }
        } catch {
            // The list keeps the card if metadata deletion fails.
        }
    }

    func matching(keyword: String) -> [BusinessCard] {
        store.search(keyword: keyword)
    }
}
