import SwiftUI
import UIKit

/// 扫描流程编排：拍摄/导入 → 区域检测 → 校正。
/// 参考 App 没有独立"扫描入口"页，底部中央相机直达拍摄，本流程同样从拍摄开始。
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case capture
        case detection
        case correction
        case result
    }

    @State private var step: Step = .capture
    @State private var originalImage: UIImage?
    @State private var corners: [CGPoint] = []
    @State private var processedImage: UIImage?

    var body: some View {
        Group {
            switch step {
            case .capture:
                CaptureView(
                    onPhoto: { data in
                        originalImage = UIImage(data: data)
                        step = .detection
                    },
                    onCancel: { dismiss() }
                )
            case .detection:
                if let originalImage {
                    DetectionView(
                        image: originalImage,
                        onDetected: { detected in
                            corners = detected
                            step = .correction
                        },
                        onCancel: { step = .capture }
                    )
                }
            case .correction:
                if let originalImage {
                    CorrectionView(
                        image: originalImage,
                        corners: corners,
                        onComplete: { processed in
                            processedImage = processed
                            step = .result
                        },
                        onCancel: { step = .detection }
                    )
                }
            case .result:
                resultView
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            if let processedImage {
                Image(uiImage: processedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 520)
            }
            Text("校正完成，OCR 识别将在批次 C 接入")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("完成") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("校正结果")
    }
}
