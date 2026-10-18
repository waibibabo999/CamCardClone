import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CardDetailViewModel {
    let cardID: UUID
    private let store: BusinessCardStore
    private let imageStore: ImageStore
    private let exportService: ExportService

    private(set) var originalImage: UIImage?
    private(set) var processedImage: UIImage?
    private(set) var errorMessage: String?
    private(set) var isExporting = false
    var exportMessage: String?

    init(
        cardID: UUID,
        store: BusinessCardStore,
        imageStore: ImageStore = ImageStore(),
        exportService: ExportService = SystemExportService()
    ) {
        self.cardID = cardID
        self.store = store
        self.imageStore = imageStore
        self.exportService = exportService
    }

    var card: BusinessCard? {
        store.cards.first { $0.id == cardID }
    }

    var storeForEditing: BusinessCardStore { store }

    func loadImages() {
        guard let card else { return }
        originalImage = try? imageStore.loadImage(fileName: card.originalImageFileName)
        processedImage = try? imageStore.loadImage(fileName: card.processedImageFileName)
    }

    func deleteCard() throws {
        guard let card else { return }
        try store.delete(id: card.id)
        try? imageStore.deleteImage(fileName: card.originalImageFileName)
        try? imageStore.deleteImage(fileName: card.processedImageFileName)
    }

    func makeVCardURL() throws -> URL {
        guard let card else { throw ContactExportError.noContactData }
        let data = try exportService.makeVCard(for: card)
        let safeName = (card.name ?? "business-card")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(card.id.uuidString.prefix(8)).vcf")
        try data.write(to: url, options: .atomic)
        return url
    }

    func saveToContacts() async {
        guard let card else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            try await exportService.saveToSystemContacts(card)
            exportMessage = "已保存到系统联系人"
        } catch {
            exportMessage = error.localizedDescription
        }
    }
}
