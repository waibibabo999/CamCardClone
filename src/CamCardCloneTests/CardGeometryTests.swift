import CoreGraphics
import XCTest
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
