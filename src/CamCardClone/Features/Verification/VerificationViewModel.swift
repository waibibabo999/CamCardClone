import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class VerificationViewModel {
    enum Phase: Equatable {
        case processing
        case noResult
        case editing
        case saved
        case failed(String)
    }

    private(set) var phase: Phase = .processing
    private(set) var rawText: String = ""
    private(set) var fields: [CardField] = []
    private(set) var additionalEmails: [String] = []
    private(set) var additionalPhones: [String] = []
    var saveError: String?

    private let originalImage: UIImage
    private let processedImage: UIImage
    private let ocrService: OCRService
    private let parser: FieldParserService
    private let store: BusinessCardStore
    private let imageStore: ImageStore

    init(
        originalImage: UIImage,
        processedImage: UIImage,
        store: BusinessCardStore,
        ocrService: OCRService = VisionOCRService(),
        parser: FieldParserService = RuleBasedFieldParser()
    ) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.store = store
        self.ocrService = ocrService
        self.parser = parser
        self.imageStore = ImageStore()
    }

    func run() async {
        do {
            let result = try await ocrService.recognizeText(in: processedImage, languages: ["zh-Hans", "en-US"])
            rawText = result.rawText
            let parsed = parser.parse(ocrResult: result)
            fields = parsed.fields
            additionalEmails = parsed.additionalEmails
            additionalPhones = parsed.additionalPhones
            let hasAnyValue = fields.contains { $0.value != nil }
            phase = hasAnyValue ? .editing : .noResult
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        phase = .processing
        await run()
    }

    func beginManualEntry() {
        fields = FieldKey.allCases.map { CardField(key: $0, value: nil, source: .empty) }
        phase = .editing
    }

    func resetToOCR() {
        let result = parser.parse(ocrResult: OCRResult(rawText: rawText))
        fields = result.fields
        additionalEmails = result.additionalEmails
        additionalPhones = result.additionalPhones
        phase = fields.contains { $0.value != nil } ? .editing : .noResult
    }

    func updateField(key: FieldKey, value: String?) {
        guard let index = fields.firstIndex(where: { $0.key == key }) else { return }
        fields[index].value = value
        fields[index].source = value == nil ? .empty : .user
    }

    func value(for key: FieldKey) -> String? {
        fields.first(where: { $0.key == key })?.value
    }

    func setAdditionalPhones(_ text: String) {
        additionalPhones = lines(from: text)
    }

    func setAdditionalEmails(_ text: String) {
        additionalEmails = lines(from: text)
    }

    var additionalPhonesText: String {
        additionalPhones.joined(separator: "\n")
    }

    var additionalEmailsText: String {
        additionalEmails.joined(separator: "\n")
    }

    func save() {
        do {
            try persist()
            phase = .saved
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func persist() throws {
        guard let originalData = originalImage.jpegData(compressionQuality: 0.9),
              let processedData = processedImage.jpegData(compressionQuality: 0.9) else {
            throw VerificationError.imageEncodingFailed
        }

        let id = UUID()
        let originalFileName = try imageStore.saveOriginal(originalData, cardID: id)
        do {
            let processedFileName = try imageStore.saveProcessed(processedData, cardID: id)
            let card = BusinessCard(
                id: id,
                originalImageFileName: originalFileName,
                processedImageFileName: processedFileName,
                name: value(for: .name),
                company: value(for: .company),
                jobTitle: value(for: .jobTitle),
                mobile: value(for: .mobile),
                phone: value(for: .phone),
                fax: value(for: .fax),
                email: value(for: .email),
                website: value(for: .website),
                address: value(for: .address),
                department: value(for: .department),
                postalCode: value(for: .postalCode),
                notes: value(for: .notes),
                tags: [],
                additionalEmails: additionalEmails,
                additionalPhones: additionalPhones,
                ocrRawText: rawText
            )
            do {
                try store.add(card)
            } catch {
                try? imageStore.deleteImage(fileName: originalFileName)
                try? imageStore.deleteImage(fileName: processedFileName)
                throw error
            }
        } catch {
            try? imageStore.deleteImage(fileName: originalFileName)
            throw error
        }
    }

    private func lines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum VerificationError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "图片编码失败，无法保存"
        }
    }
}
