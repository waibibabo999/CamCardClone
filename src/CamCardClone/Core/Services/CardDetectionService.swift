import CoreGraphics
import UIKit
import Vision

/// 名片区域检测结果。corners 为归一化坐标（0...1），原点在**左下角**，顺序为：
/// topLeft, topRight, bottomRight, bottomLeft。与 Core Image 坐标系一致，可直接换算。
struct CardDetectionResult: Equatable {
    var corners: [CGPoint]
    var confidence: Double
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
                guard let observation = request.results?.first as? VNRectangleObservation else {
                    continuation.resume(throwing: CardDetectionError.noCardFound)
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
                    confidence: Double(observation.confidence)
                ))
            }
            request.minimumAspectRatio = 0.4
            request.maximumAspectRatio = 1.0
            request.quadratureTolerance = 20
            request.minimumSize = 0.2

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
