import Foundation
import UIKit

/// 名片图片的持久化。图片存 Documents/Images/，文件名格式 `<cardID>_<original|processed>.jpg`。
struct ImageStore {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.baseURL = documents.appendingPathComponent("Images", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
    }

    private func url(for fileName: String) -> URL {
        baseURL.appendingPathComponent(fileName)
    }

    func saveOriginal(_ data: Data, cardID: UUID) throws -> String {
        try save(data, cardID: cardID, suffix: "original")
    }

    func saveProcessed(_ data: Data, cardID: UUID) throws -> String {
        try save(data, cardID: cardID, suffix: "processed")
    }

    private func save(_ data: Data, cardID: UUID, suffix: String) throws -> String {
        let fileName = "\(cardID.uuidString)_\(suffix).jpg"
        try data.write(to: url(for: fileName), options: [.atomic])
        return fileName
    }

    func loadImage(fileName: String) throws -> UIImage {
        let data = try Data(contentsOf: url(for: fileName))
        guard let image = UIImage(data: data) else {
            throw ImageStoreError.corruptedImage(fileName)
        }
        return image.normalizedUp
    }

    func deleteImage(fileName: String) throws {
        let target = url(for: fileName)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }
}

enum ImageStoreError: LocalizedError {
    case corruptedImage(String)

    var errorDescription: String? {
        switch self {
        case .corruptedImage(let fileName):
            return "图片文件损坏：\(fileName)"
        }
    }
}
