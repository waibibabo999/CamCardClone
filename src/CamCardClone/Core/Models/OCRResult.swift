import Foundation

/// 归一化矩形：相对原图，坐标原点在左上角，四个值取值范围均为 0...1。
struct NormalizedRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct OCRObservation: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var confidence: Double
    var boundingBox: NormalizedRect

    init(id: UUID = UUID(), text: String, confidence: Double, boundingBox: NormalizedRect) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// OCR 原始输出。`rawText` 必须完整保存，用于追溯与错误分析，不能只保留最终字段。
struct OCRResult: Codable, Hashable {
    var rawText: String
    var observations: [OCRObservation]
    var createdAt: Date

    init(rawText: String, observations: [OCRObservation] = [], createdAt: Date = Date()) {
        self.rawText = rawText
        self.observations = observations
        self.createdAt = createdAt
    }
}
