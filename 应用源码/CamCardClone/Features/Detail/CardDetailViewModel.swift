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
    private(set) var backImage: UIImage?
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
        originalImage = card.originalImageFileName.flatMap {
            try? imageStore.loadImage(fileName: $0)
        }
        processedImage = card.processedImageFileName.flatMap {
            try? imageStore.loadImage(fileName: $0)
        }
        backImage = card.backImageFileName.flatMap {
            try? imageStore.loadImage(fileName: $0)
        }
    }

    func saveBackImage(_ image: UIImage) throws {
        guard let card,
              let data = image.jpegData(compressionQuality: 0.9) else {
            throw CardDetailError.imageEncodingFailed
        }

        let fileName = try imageStore.saveBack(data, cardID: card.id)
        do {
            var updated = card
            updated.backImageFileName = fileName
            try store.update(updated)
            if let previous = card.backImageFileName, previous != fileName {
                try? imageStore.deleteImage(fileName: previous)
            }
            backImage = image
        } catch {
            try? imageStore.deleteImage(fileName: fileName)
            throw error
        }
    }

    func replaceFrontImage(_ image: UIImage) throws {
        guard let card,
              let data = image.jpegData(compressionQuality: 0.9) else {
            throw CardDetailError.imageEncodingFailed
        }

        let fileName = try imageStore.saveProcessed(data, cardID: card.id)
        var updated = card
        let previousFileName = card.processedImageFileName
        updated.processedImageFileName = fileName
        try store.update(updated)
        if let previousFileName, previousFileName != fileName {
            try? imageStore.deleteImage(fileName: previousFileName)
        }
        processedImage = image
    }

    func deleteFrontImage() throws {
        guard let card else { return }
        var updated = card
        let originalName = card.originalImageFileName
        let processedName = card.processedImageFileName
        updated.originalImageFileName = nil
        updated.processedImageFileName = nil
        try store.update(updated)
        if let originalName {
            try? imageStore.deleteImage(fileName: originalName)
        }
        if let processedName, processedName != originalName {
            try? imageStore.deleteImage(fileName: processedName)
        }
        originalImage = nil
        processedImage = nil
    }

    func deleteBackImage() throws {
        guard let card, let backImageFileName = card.backImageFileName else { return }
        var updated = card
        updated.backImageFileName = nil
        try store.update(updated)
        try? imageStore.deleteImage(fileName: backImageFileName)
        backImage = nil
    }

    func deleteCard() throws {
        guard let card else { return }
        try store.delete(id: card.id)
        if let originalImageFileName = card.originalImageFileName {
            try? imageStore.deleteImage(fileName: originalImageFileName)
        }
        if let processedImageFileName = card.processedImageFileName,
           processedImageFileName != card.originalImageFileName {
            try? imageStore.deleteImage(fileName: processedImageFileName)
        }
        if let backImageFileName = card.backImageFileName {
            try? imageStore.deleteImage(fileName: backImageFileName)
        }
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

enum CardDetailError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "照片编码失败"
        }
    }
}
