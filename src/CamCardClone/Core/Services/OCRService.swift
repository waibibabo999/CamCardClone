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

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let items = observations.compactMap { observation -> OCRObservation? in
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
                let rawText = items.map(\.text).joined(separator: "\n")
                continuation.resume(returning: OCRResult(rawText: rawText, observations: items))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
