import CoreImage
import Foundation
import UIKit
import Vision

protocol OCRService {
    func recognizeText(in image: UIImage, languages: [String]) async throws -> OCRResult
}

enum OCRServiceError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "图片无法读取"
        }
    }
}

/// 基于 Vision VNRecognizeTextRequest 的实现。只返回原始文本与观察结果，不做字段解析。
struct VisionOCRService: OCRService {
    func recognizeText(in image: UIImage, languages: [String]) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRServiceError.invalidImage
        }
        let orientation = image.cgImagePropertyOrientation
        return try await Task.detached(priority: .userInitiated) {
            let enhancedImage = Self.highContrastOCRImage(from: cgImage)
            let originalRequest = Self.makeRequest(languages: languages)
            let contrastRequest = Self.makeRequest(languages: languages)
            let supplementaryRequest = languages.contains(where: {
                $0.lowercased().hasPrefix("zh")
            }) ? Self.makeRequest(languages: ["en-US"]) : nil
            let supplementImage = supplementaryRequest.map { _ in
                Self.contactSupplementImage(from: cgImage)
            }

            var originalItems: [OCRObservation]?
            var supplementaryItems: [OCRObservation]?
            var originalError: Error?
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        let handler = VNImageRequestHandler(
                            cgImage: cgImage,
                            orientation: orientation,
                            options: [:]
                        )
                        try handler.perform([originalRequest])
                        originalItems = Self.observations(from: originalRequest)
                    } catch {
                        originalError = error
                    }
                    group.leave()
                }
            }

            if let supplementaryRequest, let supplementImage {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        do {
                            let handler = VNImageRequestHandler(
                                cgImage: supplementImage,
                                orientation: orientation,
                                options: [:]
                            )
                            try handler.perform([supplementaryRequest])
                            supplementaryItems = Self.observations(from: supplementaryRequest)
                        } catch {
                            // The primary OCR remains usable if the optional
                            // English contact repair fails.
                        }
                        group.leave()
                    }
                }
            }

            group.wait()
            guard var primaryItems = originalItems else {
                throw originalError ?? OCRServiceError.invalidImage
            }
            if primaryItems.count < 3 {
                let handler = VNImageRequestHandler(
                    cgImage: enhancedImage,
                    orientation: orientation,
                    options: [:]
                )
                try handler.perform([contrastRequest])
                let contrastItems = Self.observations(from: contrastRequest)
                if Self.observationSetScore(contrastItems) > Self.observationSetScore(primaryItems) {
                    primaryItems = contrastItems
                }
            }

            var items = primaryItems
            if let supplementaryItems {
                items = Self.mergeContactObservations(
                    primary: items,
                    supplementary: supplementaryItems
                )
            }
            items.sort(by: Self.readingOrder)
            return OCRResult(
                rawText: items.map(\.text).joined(separator: "\n"),
                observations: items
            )
        }.value
    }

    private static func observationSetScore(_ items: [OCRObservation]) -> Double {
        let text = items.map(\.text).joined(separator: "\n")
        let cjkCount = text.unicodeScalars.filter {
            (0x4E00...0x9FFF).contains($0.value)
        }.count
        let contactCount = items.filter {
            $0.text.contains("@")
                || $0.text.filter(\.isNumber).count >= 7
        }.count
        let confidence = items.isEmpty
            ? 0
            : items.reduce(0) { $0 + $1.confidence } / Double(items.count)
        return Double(text.count) + Double(cjkCount) * 3
            + Double(contactCount) * 25 + confidence * 10
    }

    private static func highContrastOCRImage(from cgImage: CGImage) -> CGImage {
        let input = CIImage(cgImage: cgImage)
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(input, forKey: kCIInputImageKey)
        controls?.setValue(0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.22, forKey: kCIInputContrastKey)
        controls?.setValue(0.015, forKey: kCIInputBrightnessKey)
        guard let controlled = controls?.outputImage else { return cgImage }

        let sharp = CIFilter(name: "CIUnsharpMask")
        sharp?.setValue(controlled, forKey: kCIInputImageKey)
        sharp?.setValue(1.1, forKey: kCIInputRadiusKey)
        sharp?.setValue(0.3, forKey: kCIInputIntensityKey)
        guard let output = sharp?.outputImage,
              let rendered = CIContext().createCGImage(output, from: output.extent) else {
            return cgImage
        }
        return rendered
    }

    /// Small card crops often lose the last digits of a phone or the `@` in an
    /// email. Lanczos upscaling gives the English contact pass more pixels to
    /// work with without blocking the main thread.
    private static func contactSupplementImage(from cgImage: CGImage) -> CGImage {
        let longestSide = max(cgImage.width, cgImage.height)
        guard longestSide < 1_000 else { return cgImage }

        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            return cgImage
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(3, forKey: kCIInputScaleKey)
        filter.setValue(1, forKey: kCIInputAspectRatioKey)
        guard let output = filter.outputImage,
              let scaled = CIContext().createCGImage(output, from: output.extent) else {
            return cgImage
        }
        return scaled
    }

    private static func makeRequest(languages: [String]) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        return request
    }

    private static func observations(from request: VNRecognizeTextRequest) -> [OCRObservation] {
        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        return observations.compactMap { observation -> OCRObservation? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return OCRObservation(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                boundingBox: NormalizedRect(
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.size.width),
                    height: Double(box.size.height)
                )
            )
        }
    }

    /// Mixed-language recognition occasionally turns `@` into a CJK glyph or
    /// damages the Latin half of a bilingual company name. A parallel English
    /// pass repairs those overlapping lines without replacing Chinese text.
    private static func mergeContactObservations(
        primary: [OCRObservation],
        supplementary: [OCRObservation]
    ) -> [OCRObservation] {
        var merged = primary
        for candidate in supplementary
        where isContactLike(candidate.text) || latinTokens(in: candidate.text).count >= 2 {
            if let index = merged.firstIndex(where: { overlap($0.boundingBox, candidate.boundingBox) > 0.28 }) {
                let primaryText = merged[index].text
                if let corrected = bilingualCorrection(
                    primary: primaryText,
                    supplementary: candidate.text
                ) {
                    var replacement = candidate
                    replacement.text = corrected
                    merged[index] = replacement
                    continue
                }
                if contactQuality(candidate.text) > contactQuality(primaryText) {
                    var replacement = candidate
                    replacement.text = mergedContactText(
                        primary: primaryText,
                        supplementary: candidate.text
                    )
                    merged[index] = replacement
                }
            } else if isEmailLike(candidate.text) {
                // 不追加英文辅助识别中未匹配的纯数字文本，避免把桌面工具栏
                // 上的长数字误认为电话号码。
                merged.append(candidate)
            }
        }
        return merged
    }

    static func bilingualCorrection(primary: String, supplementary: String) -> String? {
        guard primary.unicodeScalars.contains(where: {
            (0x4E00...0x9FFF).contains($0.value)
        }) else {
            return nil
        }
        let primaryTokens = latinTokens(in: primary)
        let supplementaryTokens = latinTokens(in: supplementary)
        guard !primaryTokens.isEmpty,
              !supplementaryTokens.isEmpty,
              supplementaryTokens.count <= 6 else {
            return nil
        }
        let primarySet = Set(primaryTokens.map { $0.lowercased() })
        guard supplementaryTokens.contains(where: {
            primarySet.contains($0.lowercased())
        }) else {
            return nil
        }

        guard let firstLatin = primary.range(of: "[A-Za-z]", options: .regularExpression) else {
            return nil
        }
        let prefix = primary[..<firstLatin.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let correctedLatin = supplementaryTokens.joined(separator: " ")
        let originalLatin = primaryTokens.joined(separator: " ")
        guard correctedLatin.caseInsensitiveCompare(originalLatin) != .orderedSame,
              correctedLatin.count <= originalLatin.count * 2 else {
            return nil
        }
        return prefix.isEmpty ? correctedLatin : "\(prefix) \(correctedLatin)"
    }

    private static func latinTokens(in text: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: #"[A-Za-z]{3,}"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func isEmailLike(_ text: String) -> Bool {
        guard let at = text.firstIndex(of: "@") else { return false }
        let domain = text[text.index(after: at)...]
        return text[..<at].contains(where: { $0.isLetter || $0.isNumber })
            && domain.contains(".")
    }

    private static func mergedContactText(primary: String, supplementary: String) -> String {
        if supplementary.contains("@") {
            return supplementary
        }
        let tokenStart = supplementary.firstIndex(where: {
            $0 == "+" || $0.isNumber
        })
        guard let tokenStart else { return supplementary }
        let token = String(supplementary[tokenStart...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = ["手机", "电话", "传真"].first(where: primary.contains)
        return prefix.map { "\($0)：\(token)" } ?? token
    }

    private static func isContactLike(_ text: String) -> Bool {
        let lower = text.lowercased()
        return text.contains("@")
            || lower.contains("www.")
            || lower.contains("http")
            || text.filter(\.isNumber).count >= 7
    }

    private static func contactQuality(_ text: String) -> Int {
        let lower = text.lowercased()
        return (text.contains("@") ? 100 : 0)
            + (lower.contains("www.") || lower.contains("http") ? 40 : 0)
            + text.filter(\.isNumber).count
    }

    private static func overlap(_ lhs: NormalizedRect, _ rhs: NormalizedRect) -> Double {
        let left = max(lhs.x, rhs.x)
        let right = min(lhs.x + lhs.width, rhs.x + rhs.width)
        let top = min(lhs.y + lhs.height, rhs.y + rhs.height)
        let bottom = max(lhs.y, rhs.y)
        let intersection = max(0, right - left) * max(0, top - bottom)
        let union = lhs.width * lhs.height + rhs.width * rhs.height - intersection
        return union > 0 ? intersection / union : 0
    }

    /// Vision does not guarantee result order. Reconstruct normal top-to-bottom,
    /// left-to-right reading order before the deterministic field parser sees it.
    private static func readingOrder(
        _ lhs: OCRObservation,
        _ rhs: OCRObservation
    ) -> Bool {
        let left = lhs.boundingBox
        let right = rhs.boundingBox
        let leftMidY = left.y + left.height / 2
        let rightMidY = right.y + right.height / 2
        let rowTolerance = max(min(left.height, right.height), 0.008) * 0.65
        if abs(leftMidY - rightMidY) > rowTolerance {
            return leftMidY > rightMidY
        }
        if abs(left.x - right.x) > 0.01 {
            return left.x < right.x
        }
        return leftMidY > rightMidY
    }
}
