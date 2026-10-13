import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    @State private var viewModel: CaptureViewModel
    @State private var pickerItem: PhotosPickerItem?

    @MainActor
    init(onPhoto: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.onPhoto = onPhoto
        self.onCancel = onCancel
        _viewModel = State(initialValue: CaptureViewModel())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.screen {
            case .permissionDenied:
                permissionDeniedView
            case .captured:
                capturedView
            default:
                cameraPreview
            }
        }
        .task { await viewModel.prepare() }
        .onDisappear { viewModel.stop() }
        .onChange(of: pickerItem) { _, item in
            loadImport(item)
        }
        .navigationTitle("拍摄名片")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { onCancel() }
            }
        }
    }

    private var cameraPreview: some View {
        VStack {
            ZStack {
                if viewModel.screen == .loading {
                    ProgressView()
                        .tint(.white)
                }
                CameraPreviewView(session: viewModel.session)
            }
            Spacer()
            shutterBar
        }
    }

    private var shutterBar: some View {
        HStack(spacing: 48) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("相册")
                        .font(.caption)
                }
                .foregroundStyle(.white)
            }

            Button {
                viewModel.capture()
            } label: {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().fill(.white).padding(6))
            }
            .disabled(viewModel.screen != .ready)

            Color.clear.frame(width: 48, height: 48)
        }
        .padding(.bottom, 24)
    }

    private var capturedView: some View {
        VStack {
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: .infinity)
            }
            HStack(spacing: 24) {
                Button("重拍") { viewModel.retake() }
                    .buttonStyle(.bordered)
                Button("确认") {
                    if let image = viewModel.capturedImage,
                       let data = image.jpegData(compressionQuality: 0.9) {
                        onPhoto(data)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 24)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
            Text("无法访问相机")
                .font(.headline)
            Text(viewModel.errorMessage ?? "请在设置中打开相机权限")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("前往设置") { viewModel.openSettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// 把 AVCaptureVideoPreviewLayer 包装成 SwiftUI 视图。
private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private extension CaptureView {
    func loadImport(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { onPhoto(data) }
            }
        }
    }
}
