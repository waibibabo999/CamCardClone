import SwiftUI
import UIKit

struct DetectionView: View {
    let image: UIImage
    let onDetected: ([CGPoint]) -> Void
    let onCancel: () -> Void

    @State private var viewModel: DetectionViewModel

    @MainActor
    init(image: UIImage, onDetected: @escaping ([CGPoint]) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onDetected = onDetected
        self.onCancel = onCancel
        _viewModel = State(initialValue: DetectionViewModel())
    }

    var body: some View {
        VStack(spacing: 16) {
            imageLayer
                .frame(maxHeight: 440)
            statusArea
        }
        .padding()
        .navigationTitle("检测名片")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { onCancel() }
            }
        }
        .task { await viewModel.detect(in: image) }
    }

    private var imageLayer: some View {
        GeometryReader { geo in
            let fitted = CardGeometry.aspectFitRect(imageSize: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                if case .detected(let corners) = viewModel.state {
                    let points = CardGeometry.normalizedToView(corners, size: fitted.size)
                        .map { CGPoint(x: $0.x + fitted.minX, y: $0.y + fitted.minY) }
                    QuadPath(points: points)
                }
            }
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        switch viewModel.state {
        case .detecting:
            ProgressView("正在检测名片…")
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("手动调整") { onDetected(CardGeometry.fullFrameCorners) }
                        .buttonStyle(.bordered)
                    Button("重拍") { onCancel() }
                        .buttonStyle(.borderedProminent)
                }
            }
        case .detected(let corners):
            VStack(spacing: 10) {
                if viewModel.usedFallback {
                    Text("未检测到完整名片，已使用整张图片。请在下一步手动调整四角。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("确认") { onDetected(corners) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// 展示检测到的四边形与四角标记（不可拖拽，仅展示）。
struct QuadPath: View {
    let points: [CGPoint]

    var body: some View {
        Path { path in
            guard points.count == 4 else { return }
            path.move(to: points[0])
            path.addLine(to: points[1])
            path.addLine(to: points[2])
            path.addLine(to: points[3])
            path.closeSubpath()
        }
        .stroke(Color.yellow, lineWidth: 2)
        .overlay {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 10, height: 10)
                    .position(point)
            }
        }
    }
}
