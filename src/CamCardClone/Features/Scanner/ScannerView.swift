import SwiftUI
import UIKit

/// 扫描流程编排：拍摄/导入 → 区域检测 → 校正 → OCR + 人工确认 → 保存。
/// 参考 App 没有独立"扫描入口"页，底部中央相机直达拍摄，本流程同样从拍摄开始。
struct ScannerView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case capture
        case detection
        case correction
        case verification
    }

    @State private var step: Step = .capture
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var corners: [CGPoint] = []

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
                            step = .verification
                        },
                        onCancel: { step = .detection }
                    )
                }
            case .verification:
                if let originalImage, let processedImage {
                    VerificationView(
                        originalImage: originalImage,
                        processedImage: processedImage,
                        store: store,
                        onSaved: { dismiss() },
                        onRetake: { step = .capture }
                    )
                }
            }
        }
    }
}
