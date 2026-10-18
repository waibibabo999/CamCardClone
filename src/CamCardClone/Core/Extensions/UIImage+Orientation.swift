import ImageIO
import UIKit

extension UIImage {
    /// Returns a bitmap whose pixels are already in the displayed orientation.
    /// Vision and Core Image work on the raw pixels, so normalizing once at the
    /// capture/import boundary keeps detection, OCR and perspective correction
    /// consistent with what the user sees.
    var normalizedUp: UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
