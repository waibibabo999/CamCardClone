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
    private(set) var usedFullImageFallback = false
    private(set) var displayProcessedImage: UIImage
    var saveError: String?

    private let originalImage: UIImage
    private let processedImage: UIImage
    private let ocrService: OCRService
    private let parser: FieldParserService
    private let store: BusinessCardStore
    private let imageStore: ImageStore
    private let initialTags: [String]

    init(
        originalImage: UIImage,
        processedImage: UIImage,
        store: BusinessCardStore,
        initialTags: [String] = [],
        ocrService: OCRService = VisionOCRService(),
        parser: FieldParserService = RuleBasedFieldParser()
    ) {
        self.originalImage = originalImage
        self.processedImage = processedImage
        self.store = store
        self.initialTags = initialTags
        self.ocrService = ocrService
        self.parser = parser
        self.imageStore = ImageStore()
        self.displayProcessedImage = processedImage
    }

    func run() async {
        do {
            let selection = try await recognizeBestResult()
            rawText = selection.result.rawText
            usedFullImageFallback = selection.usedOriginalImage
            displayProcessedImage = selection.displayImage
            let parsed = selection.parsed
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

    var processedImageForDisplay: UIImage {
        displayProcessedImage
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
              let processedData = displayProcessedImage.jpegData(compressionQuality: 0.9) else {
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
                tags: initialTags,
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

    private struct RecognitionSelection {
        let result: OCRResult
        let parsed: ParsedFields
        var displayImage: UIImage
        let usedOriginalImage: Bool
        let score: Double
    }

    private func recognizeBestResult() async throws -> RecognitionSelection {
        let languages = ["zh-Hans", "zh-Hant", "en-US"]
        var best: RecognitionSelection?
        var lastError: Error?

        let processedCandidates = orientationCandidates(for: processedImage)
        for (index, candidateImage) in processedCandidates.enumerated() {
            do {
                let result = try await ocrService.recognizeText(
                    in: candidateImage,
                    languages: languages
                )
                let parsed = parser.parse(ocrResult: result)
                let selection = RecognitionSelection(
                    result: result,
                    parsed: parsed,
                    displayImage: candidateImage,
                    usedOriginalImage: false,
                    score: recognitionScore(result: result, parsed: parsed)
                )
                if best == nil || selection.score > best!.score {
                    best = selection
                }
                if index == 0, meaningfulFieldCount(in: parsed) >= 2 {
                    break
                }
            } catch {
                lastError = error
            }
        }

        guard var best else {
            throw lastError ?? OCRServiceError.invalidImage
        }

        // Full-frame OCR is a last resort. Running it whenever the crop has
        // only a few fields can pull dates and desktop UI into the contact.
        if meaningfulFieldCount(in: best.parsed) < 2 {
            for candidateImage in orientationCandidates(for: originalImage) {
                do {
                    let result = try await ocrService.recognizeText(
                        in: candidateImage,
                        languages: languages
                    )
                    let parsed = parser.parse(ocrResult: result)
                    let originalCount = meaningfulFieldCount(in: parsed)
                    let processedCount = meaningfulFieldCount(in: best.parsed)
                    guard originalCount >= processedCount + 2 else { continue }
                    best = RecognitionSelection(
                        result: result,
                        parsed: parsed,
                        displayImage: best.displayImage,
                        usedOriginalImage: true,
                        score: recognitionScore(result: result, parsed: parsed)
                    )
                } catch {
                    lastError = error
                }
            }
        }
        return best
    }

    private func orientationCandidates(for image: UIImage) -> [UIImage] {
        guard let cgImage = image.cgImage else { return [image] }
        if cgImage.height > cgImage.width {
            return [
                UIImage(cgImage: cgImage, scale: image.scale, orientation: .left),
                image,
                UIImage(cgImage: cgImage, scale: image.scale, orientation: .right)
            ]
        }
        return [image]
    }

    private func meaningfulFieldCount(in parsed: ParsedFields) -> Int {
        parsed.fields.filter { $0.value != nil }.count
            + parsed.additionalEmails.count
            + parsed.additionalPhones.count
    }

    private func recognitionScore(result: OCRResult, parsed: ParsedFields) -> Double {
        let values = Double(meaningfulFieldCount(in: parsed))
        let confidence = result.observations.isEmpty
            ? 0
            : result.observations.reduce(0) { $0 + $1.confidence }
                / Double(result.observations.count)
        let textBonus = min(Double(result.rawText.count), 300) * 0.01
        return values * 100 + confidence * 10 + textBonus
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
