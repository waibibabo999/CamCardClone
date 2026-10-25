import PhotosUI
import SwiftUI
import UIKit

/// 扫描流程编排：入口 → 拍摄/导入 → 区域检测 → 校正 → OCR + 人工确认 → 保存。
///
/// 入口页把"拍摄"和"从相册导入"分开：模拟器没有摄像头，但相册导入可用，
/// 这样在机房里不用真机也能验证检测 → 校正 → OCR → 保存这条主链。
struct ScannerView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case entry
        case capture
        case detection
        case correction
        case verification
    }

    @State private var step: Step = .capture
    @State private var originalImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var corners: [CGPoint] = []
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        Group {
            switch step {
            case .entry:
                entryView
            case .capture:
                CaptureView(
                    onPhoto: { data in
                        originalImage = UIImage(data: data)?.normalizedUp
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
                        onRetake: { step = .capture },
                        onCancel: { step = .capture }
                    )
                }
            }
        }
        .onChange(of: pickedItem) { _, item in
            loadPicked(item)
        }
    }

    private var entryView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Theme.textSecondary)
            Text("扫描名片")
                .font(.title2.bold())
            Text("拍摄一张名片，或从相册导入")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            Button {
                step = .capture
            } label: {
                Label("拍摄名片", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("从相册导入", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .padding()
        .navigationTitle("扫描名片")
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            await MainActor.run {
                originalImage = UIImage(data: data)?.normalizedUp
                step = .detection
            }
        }
    }
}
