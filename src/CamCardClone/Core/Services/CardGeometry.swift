import CoreGraphics
import Foundation

/// 纯坐标换算，便于单元测试。
/// 归一化坐标统一为 0...1；display 空间原点在**左上角**，image/CI 空间原点在**左下角**。
enum CardGeometry {
    /// 整幅图的四个角（归一化、左下原点），用于“检测失败 → 手动调整”时作为初始框。
    /// 顺序：topLeft, topRight, bottomRight, bottomLeft。
    static let fullFrameCorners: [CGPoint] = [
        CGPoint(x: 0, y: 1),
        CGPoint(x: 1, y: 1),
        CGPoint(x: 1, y: 0),
        CGPoint(x: 0, y: 0)
    ]

    /// 归一化（左下原点）→ Core Image 像素坐标（左下原点）。直接缩放，无需翻转。
    static func normalizedToImage(_ points: [CGPoint], size: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    /// 归一化（左下原点）→ 视图坐标（左上原点），用于叠加绘制。
    static func normalizedToView(_ points: [CGPoint], size: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }
    }

    /// 视图坐标（左上原点）→ 归一化（左下原点），用于手势拖拽后写回。
    static func viewToNormalized(_ points: [CGPoint], size: CGSize) -> [CGPoint] {
        guard size.width > 0, size.height > 0 else { return points }
        return points.map { CGPoint(x: $0.x / size.width, y: 1 - $0.y / size.height) }
    }

    /// 在容器内按 aspect-fit 计算图片显示区域。
    static func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: (container.width - width) / 2,
            y: (container.height - height) / 2,
            width: width,
            height: height
        )
    }

    /// 旋转角点顺序：把四角按顺时针方向平移 oneStep 个位置。
    /// 输入输出顺序均为 topLeft, topRight, bottomRight, bottomLeft。
    static func rotated(_ corners: [CGPoint], steps: Int) -> [CGPoint] {
        guard corners.count == 4 else { return corners }
        let shift = ((steps % 4) + 4) % 4
        guard shift != 0 else { return corners }
        return (0..<4).map { corners[($0 + shift) % 4] }
    }
}
