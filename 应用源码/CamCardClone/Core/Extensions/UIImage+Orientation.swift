import ImageIO
import UIKit
import CoreImage

extension UIImage {
    /// Decode camera/photo-library data off the main thread at a size that is
    /// still generous enough for OCR. ImageIO applies EXIF orientation while
    /// creating the thumbnail, avoiding a full-resolution redraw.
    static func cardScanImage(from data: Data, maxPixelSize: Int = 3_200) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// Crop using normalized top-left coordinates. The capture guide already
    /// matches what the user framed, so this is applied before detection.
    func cropped(toNormalizedRect rect: CGRect) -> UIImage? {
        guard let cgImage else { return nil }
        let normalized = CGRect(
            x: min(max(rect.minX, 0), 1),
            y: min(max(rect.minY, 0), 1),
            width: min(max(rect.width, 0.01), 1),
            height: min(max(rect.height, 0.01), 1)
        )
        let pixelRect = CGRect(
            x: normalized.minX * CGFloat(cgImage.width),
            y: normalized.minY * CGFloat(cgImage.height),
            width: normalized.width * CGFloat(cgImage.width),
            height: normalized.height * CGFloat(cgImage.height)
        ).integral.intersection(
            CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        )
        guard pixelRect.width > 1, pixelRect.height > 1,
              let cropped = cgImage.cropping(to: pixelRect) else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

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

    var rotatedClockwise: UIImage {
        guard let input = CIImage(image: self) else { return self }
        let output = input.oriented(.right)
        guard let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return self
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
