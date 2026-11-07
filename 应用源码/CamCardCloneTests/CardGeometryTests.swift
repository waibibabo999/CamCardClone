import CoreGraphics
import XCTest
import UIKit
@testable import CamCardClone

final class CardGeometryTests: XCTestCase {
    func testFullFrameCornersCoverWholeImage() {
        let size = CGSize(width: 200, height: 100)
        let imageCorners = CardGeometry.normalizedToImage(CardGeometry.fullFrameCorners, size: size)

        XCTAssertEqual(imageCorners[0], CGPoint(x: 0, y: 100))   // topLeft（左下原点）
        XCTAssertEqual(imageCorners[2], CGPoint(x: 200, y: 0))   // bottomRight
    }

    func testViewAndNormalizedRoundTrip() {
        let size = CGSize(width: 300, height: 400)
        let viewPoints = CardGeometry.normalizedToView(CardGeometry.fullFrameCorners, size: size)
        let back = CardGeometry.viewToNormalized(viewPoints, size: size)

        for (original, roundTripped) in zip(CardGeometry.fullFrameCorners, back) {
            XCTAssertEqual(original.x, roundTripped.x, accuracy: 0.0001)
            XCTAssertEqual(original.y, roundTripped.y, accuracy: 0.0001)
        }
    }

    func testAspectFitRectCentersLandscapeImage() {
        let imageSize = CGSize(width: 200, height: 100)
        let container = CGSize(width: 300, height: 300)
        let rect = CardGeometry.aspectFitRect(imageSize: imageSize, in: container)

        XCTAssertEqual(rect.width, 300, accuracy: 0.001)
        XCTAssertEqual(rect.height, 150, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 75, accuracy: 0.001)
    }

    func testRotatedCornersShiftBySteps() {
        let corners: [CGPoint] = [
            CGPoint(x: 0, y: 1),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0)
        ]
        let rotated = CardGeometry.rotated(corners, steps: 1)
        XCTAssertEqual(rotated[0], corners[1])
        XCTAssertEqual(rotated[3], corners[0])
    }
}

@MainActor
final class CardDetectionServiceTests: XCTestCase {
    func testPrefersBrightCardPanelInsideLargerScreen() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1_200)).image { context in
            UIColor(red: 0.04, green: 0.18, blue: 0.32, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 1_200))

            UIColor(red: 0.16, green: 0.34, blue: 0.46, alpha: 1).setFill()
            context.fill(CGRect(x: 50, y: 150, width: 800, height: 850))

            UIColor(red: 0.88, green: 0.9, blue: 0.91, alpha: 1).setFill()
            context.fill(CGRect(x: 200, y: 250, width: 500, height: 750))

            let name = "朱宏明 Hongming Zhu" as NSString
            name.draw(
                at: CGPoint(x: 270, y: 330),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 36),
                    .foregroundColor: UIColor.black
                ]
            )
        }

        let result = try await VisionCardDetectionService().detectCard(in: image)
        let xs = result.corners.map(\.x)
        let ys = result.corners.map(\.y)

        XCTAssertFalse(result.usedFallback)
        XCTAssertGreaterThan(xs.min() ?? 0, 0.15)
        XCTAssertLessThan(xs.max() ?? 1, 0.85)
        XCTAssertGreaterThan(ys.min() ?? 0, 0.1)
        XCTAssertLessThan(ys.max() ?? 1, 0.9)
    }

    func testNormalizedCropUsesTopLeftPhotoCoordinates() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
        }

        let cropped = image.cropped(toNormalizedRect: CGRect(
            x: 0.25,
            y: 0.25,
            width: 0.5,
            height: 0.5
        ))

        XCTAssertEqual(cropped?.size.width, 50)
        XCTAssertEqual(cropped?.size.height, 100)
    }
}
