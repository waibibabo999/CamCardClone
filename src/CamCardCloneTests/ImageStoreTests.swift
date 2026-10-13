import XCTest
import UIKit
@testable import CamCardClone

final class ImageStoreTests: XCTestCase {
    private var tempDir: URL!
    private var imageStore: ImageStore!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        imageStore = ImageStore(baseURL: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeJPEGData() throws -> Data {
        let image = try XCTUnwrap(UIImage(systemName: "doc.text"))
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }

    func testSaveAndLoadOriginalImage() throws {
        let fileName = try imageStore.saveOriginal(makeJPEGData(), cardID: UUID())
        XCTAssertTrue(fileName.hasSuffix("_original.jpg"))
        XCTAssertNotNil(try imageStore.loadImage(fileName: fileName))
    }

    func testDeleteRemovesFile() throws {
        let fileName = try imageStore.saveProcessed(makeJPEGData(), cardID: UUID())
        try imageStore.deleteImage(fileName: fileName)
        XCTAssertThrowsError(try imageStore.loadImage(fileName: fileName))
    }
}
