import PhotosUI
import SwiftUI
import UIKit

/// 扫描流程编排：入口 → 拍摄/导入 → 区域检测 → 校正 → OCR + 人工确认 → 保存。
///
/// 入口页把拍摄和相册导入分开处理；模拟器环境也可通过相册导入
/// 验证检测、校正、识别与保存的完整流程。
struct ScannerView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let initialTags: [String]

    init(initialTags: [String] = []) {
        self.initialTags = initialTags
    }

    private enum Step: Equatable {
        case entry
        case capture
        case detection
        case autoCorrection
        case correction
        case verification
    }

    @State private var step: Step = .capture
    @State private var originalImage: UIImage?
    @State private var workingImage: UIImage?
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
                    onPhoto: { image, guideCrop in
                        originalImage = image
                        workingImage = guideCrop.flatMap {
                            image.cropped(toNormalizedRect: $0)
                        } ?? image
                        step = .detection
                    },
                    onCancel: { dismiss() }
                )
            case .detection:
                if let workingImage {
                    DetectionView(
                        image: workingImage,
                        onDetected: { detected, needsManualAdjustment in
                            corners = detected
                            step = needsManualAdjustment ? .correction : .autoCorrection
                        },
                        onCancel: { step = .capture }
                    )
                }
            case .autoCorrection:
                if let workingImage {
                    AutomaticCorrectionView(
                        image: workingImage,
                        corners: corners,
                        onComplete: { processed in
                            processedImage = processed
                            step = .verification
                        },
                        onNeedsAdjustment: { step = .correction },
                        onCancel: { step = .capture }
                    )
                }
            case .correction:
                if let workingImage {
                    CorrectionView(
                        image: workingImage,
                        corners: corners,
                        onComplete: { processed in
                            processedImage = processed
                            step = .verification
                        },
                        onCancel: { step = .capture }
                    )
                }
            case .verification:
                if let originalImage, let processedImage {
                    VerificationView(
                        originalImage: originalImage,
                        processedImage: processedImage,
                        store: store,
                        initialTags: initialTags,
                        onSaved: { dismiss() },
                        onRetake: { step = .capture }
                    )
                }
            }
        }
        .onChange(of: pickedItem) { _, item in
            loadPicked(item)
        }
        .preferredColorScheme(step == .capture ? .dark : .light)
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
            let image = await Task.detached(priority: .userInitiated) {
                UIImage.cardScanImage(from: data)
            }.value
            if let image {
                await MainActor.run {
                    originalImage = image
                    workingImage = image
                    step = .detection
                }
            }
        }
    }
}

/// The common path is intentionally hands-free: detect, perspective-correct,
/// then show the processed card beside the extracted fields. Manual corner
/// adjustment is only used when automatic detection is not reliable.
private struct AutomaticCorrectionView: View {
    let onComplete: (UIImage) -> Void
    let onNeedsAdjustment: () -> Void
    let onCancel: () -> Void

    @State private var viewModel: CorrectionViewModel
    @State private var scanLineOffset: CGFloat = -1

    @MainActor
    init(
        image: UIImage,
        corners: [CGPoint],
        onComplete: @escaping (UIImage) -> Void,
        onNeedsAdjustment: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        self.onNeedsAdjustment = onNeedsAdjustment
        self.onCancel = onCancel
        _viewModel = State(initialValue: CorrectionViewModel(originalImage: image, corners: corners))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: viewModel.originalImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

                Rectangle()
                    .fill(Theme.accent.opacity(0.9))
                    .frame(height: 2)
                    .shadow(color: Theme.accent, radius: 7)
                    .padding(.horizontal, 12)
                    .offset(y: scanLineOffset * min(geometry.size.width, geometry.size.height) * 0.34)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Button("取消", action: onCancel)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    Spacer()

                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("正在去除背景并校正名片…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.68))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            scanLineOffset = -1
            withAnimation(.linear(duration: 0.75).repeatForever(autoreverses: true)) {
                scanLineOffset = 1
            }
        }
        .task {
            do {
                try await Task.sleep(nanoseconds: 220_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let image = viewModel.originalImage
            let corners = viewModel.corners
            let processed = await Task.detached(priority: .userInitiated) {
                autoreleasepool {
                    CorrectionViewModel.correctedImage(
                        from: image,
                        corners: corners,
                        rotationSteps: 0
                    )
                }
            }.value
            guard !Task.isCancelled else { return }
            if let processed {
                onComplete(processed)
            } else {
                onNeedsAdjustment()
            }
        }
    }
}
