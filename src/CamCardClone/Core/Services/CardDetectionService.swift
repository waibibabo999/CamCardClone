import CoreGraphics
import UIKit
import Vision

/// 名片区域检测结果。corners 为归一化坐标（0...1），原点在**左下角**，顺序为：
/// topLeft, topRight, bottomRight, bottomLeft。与 Core Image 坐标系一致，可直接换算。
struct CardDetectionResult: Equatable {
    var corners: [CGPoint]
    var confidence: Double
    var usedFallback: Bool = false
}

protocol CardDetectionService {
    func detectCard(in image: UIImage) async throws -> CardDetectionResult
}

enum CardDetectionError: LocalizedError {
    case invalidImage
    case noCardFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "图片无法读取"
        case .noCardFound:
            return "未检测到名片"
        }
    }
}

/// 基于 Vision VNDetectRectanglesRequest 的实现。只负责找区域，不做校正、不做 OCR。
struct VisionCardDetectionService: CardDetectionService {
    func detectCard(in image: UIImage) async throws -> CardDetectionResult {
        guard let cgImage = image.cgImage else {
            throw CardDetectionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRectangleObservation]) ?? []
                guard let observation = Self.bestCardObservation(from: observations) else {
                    continuation.resume(returning: CardDetectionResult(
                        corners: CardGeometry.fullFrameCorners,
                        confidence: 0,
                        usedFallback: true
                    ))
                    return
                }
                let corners = [
                    observation.topLeft,
                    observation.topRight,
                    observation.bottomRight,
                    observation.bottomLeft
                ]
                continuation.resume(returning: CardDetectionResult(
                    corners: corners,
                    confidence: Double(observation.confidence),
                    usedFallback: false
                ))
            }
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            request.quadratureTolerance = 30
            request.minimumSize = 0.15
            request.maximumObservations = 20

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: image.cgImagePropertyOrientation,
                options: [:]
            )
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Vision can return a logo, a photo, or another small rectangle before the
    /// actual card. Prefer the largest plausible rectangle instead of the first
    /// observation. If every candidate is tiny, return nil so the caller can
    /// fall back to the full image for manual adjustment.
    private static func bestCardObservation(
        from observations: [VNRectangleObservation]
    ) -> VNRectangleObservation? {
        let plausible = observations.filter { observation in
            let box = observation.boundingBox
            let area = Double(box.width * box.height)
            let shortSide = min(box.width, box.height)
            let ratio = Double(max(box.width, box.height) / max(shortSide, 0.001))
            return area >= 0.03 && ratio >= 0.3 && ratio <= 3.0
        }
        guard let best = plausible.max(by: {
            let lhs = $0.boundingBox
            let rhs = $1.boundingBox
            return lhs.width * lhs.height < rhs.width * rhs.height
        }) else {
            return nil
        }
        let bestBox = best.boundingBox
        return bestBox.width * bestBox.height >= 0.06 ? best : nil
    }
}
