import SwiftUI
import UIKit

struct CorrectionView: View {
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var viewModel: CorrectionViewModel

    @MainActor
    init(image: UIImage, corners: [CGPoint], onComplete: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        _viewModel = State(initialValue: CorrectionViewModel(originalImage: image, corners: corners))
    }

    var body: some View {
        GeometryReader { geo in
            let fitted = CardGeometry.aspectFitRect(imageSize: viewModel.originalImage.size, in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: viewModel.originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                DraggableQuad(
                    points: displayPoints(in: fitted),
                    onMove: { index, location in
                        viewModel.moveCorner(at: index, toViewPoint: location, in: fitted)
                    }
                )
            }
        }
        .overlay(alignment: .bottom) { controlBar }
        .navigationTitle("调整名片")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { onCancel() }
            }
        }
    }

    private func displayPoints(in fitted: CGRect) -> [CGPoint] {
        CardGeometry.normalizedToView(viewModel.corners, size: fitted.size)
            .map { CGPoint(x: $0.x + fitted.minX, y: $0.y + fitted.minY) }
    }

    private var controlBar: some View {
        HStack {
            Button {
                viewModel.rotate()
            } label: {
                Label("旋转", systemImage: "rotate.right")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("旋转 \(viewModel.rotationSteps * 90)°")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("完成") {
                if let processed = viewModel.applyCorrection() {
                    onComplete(processed)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

private struct DraggableQuad: View {
    let points: [CGPoint]
    let onMove: (Int, CGPoint) -> Void

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
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                DraggableCorner(index: index, point: point, onMove: onMove)
            }
        }
    }
}

private struct DraggableCorner: View {
    let index: Int
    let point: CGPoint
    let onMove: (Int, CGPoint) -> Void

    @State private var anchor: CGPoint?

    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let start = anchor ?? point
                        anchor = start
                        let newLocation = CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        )
                        onMove(index, newLocation)
                    }
                    .onEnded { _ in anchor = nil }
            )
    }
}
