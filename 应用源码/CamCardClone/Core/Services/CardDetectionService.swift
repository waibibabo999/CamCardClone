import CoreGraphics
import CoreImage
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

/// 使用 Vision 找矩形，并用低饱和高亮区域辅助识别屏幕中央的名片面板。
/// 检测与亮度分割都放到后台线程，避免阻塞相机页和校正动画。
struct VisionCardDetectionService: CardDetectionService {
    func detectCard(in image: UIImage) async throws -> CardDetectionResult {
        guard let cgImage = image.cgImage else {
            throw CardDetectionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let orientation = image.cgImagePropertyOrientation
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        var candidates = try Self.detectionCandidates(
                            in: cgImage,
                            orientation: orientation
                        )
                        let hasPlausibleColorResult = candidates.observation != nil
                            || (candidates.brightRegion?.score ?? 0) >= 0.62
                        if !hasPlausibleColorResult {
                            let contrastImage = Self.highContrastScanImage(from: cgImage)
                            let contrastCandidates = try Self.detectionCandidates(
                                in: contrastImage,
                                orientation: orientation
                            )
                            candidates = CardCandidates(
                                observation: contrastCandidates.observation
                                    ?? candidates.observation,
                                brightRegion: contrastCandidates.brightRegion
                                    ?? candidates.brightRegion
                            )
                        }

                        let observation = candidates.observation
                        let brightRegion = candidates.brightRegion
                        let visionScore = observation.map {
                            Self.boundingBoxScore($0.boundingBox)
                        } ?? 0

                        if let brightRegion,
                           brightRegion.score >= 0.62,
                           brightRegion.score >= visionScore {
                            continuation.resume(returning: CardDetectionResult(
                                corners: brightRegion.quadrilateral,
                                confidence: brightRegion.score,
                                usedFallback: false
                            ))
                            return
                        }

                        if let observation {
                            continuation.resume(returning: CardDetectionResult(
                                corners: [
                                    observation.topLeft,
                                    observation.topRight,
                                    observation.bottomRight,
                                    observation.bottomLeft
                                ],
                                confidence: Double(observation.confidence),
                                usedFallback: false
                            ))
                            return
                        }

                        continuation.resume(returning: CardDetectionResult(
                            corners: CardGeometry.fullFrameCorners,
                            confidence: 0,
                            usedFallback: true
                        ))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private struct CardCandidates {
        let observation: VNRectangleObservation?
        let brightRegion: ScoredBrightRegion?
    }

    private static func detectionCandidates(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> CardCandidates {
        let observations = try rectangleObservations(
            in: cgImage,
            orientation: orientation
        )
        return CardCandidates(
            observation: bestCardObservation(from: observations),
            brightRegion: bestBrightRegion(in: cgImage)
        )
    }

    private static func highContrastScanImage(from cgImage: CGImage) -> CGImage {
        let input = CIImage(cgImage: cgImage)
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(input, forKey: kCIInputImageKey)
        controls?.setValue(0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.45, forKey: kCIInputContrastKey)
        controls?.setValue(0.02, forKey: kCIInputBrightnessKey)
        guard let controlled = controls?.outputImage else { return cgImage }

        let sharp = CIFilter(name: "CIUnsharpMask")
        sharp?.setValue(controlled, forKey: kCIInputImageKey)
        sharp?.setValue(1, forKey: kCIInputRadiusKey)
        sharp?.setValue(0.25, forKey: kCIInputIntensityKey)
        guard let output = sharp?.outputImage,
              let rendered = CIContext().createCGImage(output, from: output.extent) else {
            return cgImage
        }
        return rendered
    }

    private struct BrightRegion {
        var minX: Int
        var minY: Int
        var maxX: Int
        var maxY: Int
        var pixelCount: Int

        var area: Int {
            max(1, (maxX - minX + 1) * (maxY - minY + 1))
        }

        var fillRatio: Double {
            Double(pixelCount) / Double(area)
        }

        mutating func merge(_ other: BrightRegion) {
            minX = min(minX, other.minX)
            minY = min(minY, other.minY)
            maxX = max(maxX, other.maxX)
            maxY = max(maxY, other.maxY)
            pixelCount += other.pixelCount
        }
    }

    private struct ScoredBrightRegion {
        let quadrilateral: [CGPoint]
        let score: Double
    }

    private struct ScoredObservation {
        let observation: VNRectangleObservation
        let score: Double
    }

    private static func rectangleObservations(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 3.0
        request.quadratureTolerance = 30
        request.minimumSize = 0.15
        request.maximumObservations = 40

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])
        return (request.results as? [VNRectangleObservation]) ?? []
    }

    /// Bright, low-saturation panels are better candidates than an enclosing
    /// laptop bezel or another large rectangle. This runs on a small copy, so
    /// the connected-component pass stays cheap even for a 12MP capture.
    private static func bestBrightRegion(in cgImage: CGImage) -> ScoredBrightRegion? {
        let maxDimension = 256
        let scale = min(
            1,
            Double(maxDimension) / Double(max(cgImage.width, cgImage.height))
        )
        let width = max(1, Int(Double(cgImage.width) * scale))
        let height = max(1, Int(Double(cgImage.height) * scale))
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var mask = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                let luminance = (red * 3 + green * 4 + blue) / 8
                let high = max(red, max(green, blue))
                let low = min(red, min(green, blue))
                mask[y * width + x] = luminance >= 135 && high - low <= 38
            }
        }

        var visited = [Bool](repeating: false, count: width * height)
        var regions: [BrightRegion] = []
        let neighborOffsets = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        for startY in 0..<height {
            for startX in 0..<width {
                let start = startY * width + startX
                guard mask[start], !visited[start] else { continue }

                var queue = [start]
                var head = 0
                var count = 0
                var minX = startX
                var maxX = startX
                var minY = startY
                var maxY = startY
                visited[start] = true

                while head < queue.count {
                    let index = queue[head]
                    head += 1
                    count += 1
                    let y = index / width
                    let x = index % width
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)

                    for (dx, dy) in neighborOffsets {
                        let nextX = x + dx
                        let nextY = y + dy
                        guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else {
                            continue
                        }
                        let next = nextY * width + nextX
                        guard mask[next], !visited[next] else { continue }
                        visited[next] = true
                        queue.append(next)
                    }
                }

                if count >= Int(Double(width * height) * 0.012) {
                    regions.append(BrightRegion(
                        minX: minX,
                        minY: minY,
                        maxX: maxX,
                        maxY: maxY,
                        pixelCount: count
                    ))
                }
            }
        }

        var mergedRegions = regions
        var didMerge = true
        while didMerge {
            didMerge = false
            outerLoop: for first in mergedRegions.indices {
                for second in mergedRegions.indices where second > first {
                    let lhs = mergedRegions[first]
                    let rhs = mergedRegions[second]
                    let horizontalOverlap = max(
                        0,
                        min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX) + 1
                    )
                    let verticalOverlap = max(
                        0,
                        min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY) + 1
                    )
                    let narrowerWidth = max(
                        1,
                        min(lhs.maxX - lhs.minX + 1, rhs.maxX - rhs.minX + 1)
                    )
                    let narrowerHeight = max(
                        1,
                        min(lhs.maxY - lhs.minY + 1, rhs.maxY - rhs.minY + 1)
                    )
                    let verticalGap = max(
                        0,
                        max(lhs.minY, rhs.minY) - min(lhs.maxY, rhs.maxY) - 1
                    )
                    let horizontalGap = max(
                        0,
                        max(lhs.minX, rhs.minX) - min(lhs.maxX, rhs.maxX) - 1
                    )
                    let sameColumns = Double(horizontalOverlap) / Double(narrowerWidth) >= 0.78
                        && verticalGap <= max(2, height / 40)
                    let sameRows = Double(verticalOverlap) / Double(narrowerHeight) >= 0.78
                        && horizontalGap <= max(2, width / 40)
                    guard sameColumns || sameRows else { continue }

                    var merged = lhs
                    merged.merge(rhs)
                    mergedRegions.remove(at: second)
                    mergedRegions[first] = merged
                    didMerge = true
                    break outerLoop
                }
            }
        }

        let totalPixels = Double(width * height)
        let candidates = mergedRegions.compactMap { region -> ScoredBrightRegion? in
            let regionWidth = Double(region.maxX - region.minX + 1)
            let regionHeight = Double(region.maxY - region.minY + 1)
            let normalizedWidth = regionWidth / Double(width)
            let normalizedHeight = regionHeight / Double(height)
            let area = normalizedWidth * normalizedHeight
            let ratio = max(normalizedWidth, normalizedHeight)
                / max(min(normalizedWidth, normalizedHeight), 0.001)
            let touchesEdge = region.minX <= width / 100
                || region.minY <= height / 100
                || region.maxX >= width - width / 100
                || region.maxY >= height - height / 100
            guard area >= 0.055,
                  area <= 0.75,
                  ratio >= 0.55,
                  ratio <= 2.8,
                  region.fillRatio >= 0.42,
                  Double(region.pixelCount) >= totalPixels * 0.02,
                  !touchesEdge else {
                return nil
            }

            let normalizedBox = CGRect(
                x: Double(region.minX) / Double(width),
                y: Double(region.minY) / Double(height),
                width: normalizedWidth,
                height: normalizedHeight
            )
            let score = boundingBoxScore(normalizedBox)
                + min(region.fillRatio, 1) * 0.12
            let inset = 0.006
            let top = 1 - normalizedBox.minY - inset
            let bottom = 1 - normalizedBox.maxY + inset
            let left = normalizedBox.minX + inset
            let right = normalizedBox.maxX - inset
            let quadrilateral = [
                CGPoint(x: left, y: top),
                CGPoint(x: right, y: top),
                CGPoint(x: right, y: bottom),
                CGPoint(x: left, y: bottom)
            ]
            return ScoredBrightRegion(quadrilateral: quadrilateral, score: score)
        }

        return candidates.max { $0.score < $1.score }
    }

    private static func boundingBoxScore(_ box: CGRect) -> Double {
        let width = Double(box.width)
        let height = Double(box.height)
        let area = width * height
        let ratio = max(width, height) / max(min(width, height), 0.001)
        let expectedRatio = 1.58
        let aspectScore = exp(-abs(log(ratio / expectedRatio)) * 1.25)
        let areaScore = min(area / 0.25, 1)
        let centerDistance = hypot(
            Double(box.midX) - 0.5,
            Double(box.midY) - 0.5
        )
        let centerScore = max(0, 1 - centerDistance / 0.7)
        return areaScore * 0.42 + aspectScore * 0.28 + centerScore * 0.18
    }

    /// Vision can return a logo, a photo, or another small rectangle before the
    /// actual card. Rank plausible rectangles by size, card aspect and center
    /// instead of blindly choosing the largest enclosing screen.
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
        let ranked = plausible.map {
            ScoredObservation(
                observation: $0,
                score: boundingBoxScore($0.boundingBox)
            )
        }
        guard let best = ranked.max(by: { $0.score < $1.score })?.observation else {
            return nil
        }
        let bestBox = best.boundingBox
        return bestBox.width * bestBox.height >= 0.06 ? best : nil
    }
}
