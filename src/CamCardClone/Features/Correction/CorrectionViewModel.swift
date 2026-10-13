import CoreImage
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class CorrectionViewModel {
    let originalImage: UIImage
    private(set) var corners: [CGPoint]      // 归一化，左下原点
    private(set) var rotationSteps = 0
    private(set) var processedImage: UIImage?

    init(originalImage: UIImage, corners: [CGPoint]) {
        self.originalImage = originalImage
        self.corners = corners.count == 4 ? corners : CardGeometry.fullFrameCorners
    }

    func moveCorner(at index: Int, toViewPoint point: CGPoint, in fittedRect: CGRect) {
        guard index >= 0, index < corners.count else { return }
        let local = CGPoint(x: point.x - fittedRect.minX, y: point.y - fittedRect.minY)
        let normalized = CardGeometry.viewToNormalized([local], size: fittedRect.size)[0]
        corners[index] = normalized
    }

    func rotate() {
        rotationSteps = (rotationSteps + 1) % 4
    }

    func applyCorrection() -> UIImage? {
        guard let input = CIImage(image: originalImage) else { return nil }
        let ciCorners = CardGeometry.normalizedToImage(corners, size: input.extent.size)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }

        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: ciCorners[0]), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: ciCorners[1]), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: ciCorners[2]), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: ciCorners[3]), forKey: "inputBottomLeft")

        var output = filter.outputImage
        if rotationSteps != 0 {
            output = output?.oriented(orientation)
        }
        guard let output else { return nil }

        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        processedImage = image
        return image
    }

    private var orientation: CGImagePropertyOrientation {
        switch rotationSteps {
        case 1: return .right
        case 2: return .down
        case 3: return .left
        default: return .up
        }
    }
}
