import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    let onPhoto: (Data) -> Void
    let onCancel: () -> Void

    @State private var viewModel: CaptureViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var recognitionMode: RecognitionMode = .basic
    @State private var captureMode: CaptureMode = .single
    @State private var centeredMode: CaptureMode? = .single
    @State private var modeNotice: String?
    @State private var notice: String?

    private enum RecognitionMode {
        case basic
        case highAccuracy
    }

    private enum CaptureMode: String, CaseIterable, Hashable, Identifiable {
        case continuous = "连续拍摄"
        case multi = "多张拍摄"
        case single = "单张拍摄"
        case qr = "二维码"

        var id: Self { self }
    }

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
                cameraScreen
            }
        }
        .task { await viewModel.prepare() }
        .onDisappear { viewModel.stop() }
        .onChange(of: pickerItem) { _, item in
            loadImport(item)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .alert("提示", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    private var cameraScreen: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .background(Color.black.ignoresSafeArea(edges: .top))

                    Spacer(minLength: 0)
                    documentFrame(
                        width: geometry.size.width * 0.78,
                        height: min(geometry.size.height * 0.56, 520)
                    )
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        captureModeBar
                        captureControls
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .background(Color.black.ignoresSafeArea(edges: .bottom))
                }
            }

            if viewModel.screen == .loading {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("关闭")
            .accessibilityIdentifier("closeScanButton")

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                recognitionButton(.basic, title: "基础识别")
                recognitionButton(.highAccuracy, title: "AI 高精度识别")
            }
            .padding(3)
            .background(Color.black)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))

            Spacer(minLength: 0)

            Button {
                notice = "更多识别设置不在本次作业切片内。"
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.top, 8)
    }

    private func recognitionButton(_ mode: RecognitionMode, title: String) -> some View {
        Button {
            recognitionMode = mode
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(recognitionMode == mode ? .black : .white)
                .padding(.horizontal, 18)
                .frame(height: 30)
                .background(recognitionMode == mode ? Color.white : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func documentFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.95), lineWidth: 2)

            Text("请将镜头靠近名片")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .offset(y: 10)

            VStack {
                Spacer()
                Label("轻触照亮", systemImage: "flashlight.on.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: width, height: height)
    }

    private var captureModeBar: some View {
        VStack(spacing: 5) {
            if let modeNotice {
                Text(modeNotice)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
                    .transition(.opacity)
            }

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(CaptureMode.allCases) { mode in
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    centeredMode = mode
                                    captureMode = mode
                                }
                                if mode != .single {
                                    showModeNotice(mode)
                                } else {
                                    modeNotice = nil
                                }
                            } label: {
                                VStack(spacing: 7) {
                                    Text(mode.rawValue)
                                        .font(.subheadline.weight(captureMode == mode ? .semibold : .regular))
                                        .foregroundStyle(captureMode == mode ? .white : .white.opacity(0.65))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Rectangle()
                                        .fill(captureMode == mode ? Color.blue : Color.clear)
                                        .frame(height: 2)
                                }
                                .frame(width: 68)
                            }
                            .buttonStyle(.plain)
                            .id(mode)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $centeredMode, anchor: .center)
                .contentMargins(
                    .horizontal,
                    max(0, (geometry.size.width - 68) / 2),
                    for: .scrollContent
                )
                .onChange(of: centeredMode) { _, newValue in
                    guard let newMode = newValue, newMode != captureMode else { return }
                    captureMode = newMode
                    if newMode != .single {
                        showModeNotice(newMode)
                    } else {
                        modeNotice = nil
                    }
                }
            }
            .frame(height: 42)
        }
        .padding(.top, 2)
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.2), value: modeNotice)
    }

    private func showModeNotice(_ mode: CaptureMode) {
        modeNotice = "\(mode.rawValue)不在本次功能切片内"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if captureMode == mode {
                modeNotice = nil
            }
        }
    }

    private var captureControls: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                VStack(spacing: 5) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("相册")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .frame(width: 56)
            }

            Spacer()

            Button {
                viewModel.capture()
            } label: {
                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 6)
                    .frame(width: 78, height: 78)
                    .overlay(Circle().fill(.white).padding(8))
            }
            .disabled(viewModel.screen != .ready)
            .accessibilityLabel("拍摄")
            .accessibilityIdentifier("captureButton")

            Spacer()

            Button {
                notice = "多张拍摄不在本次功能切片内。"
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "rectangle.stack")
                        .font(.title2)
                    Text("5")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .frame(width: 56)
            }
        }
        .padding(.top, 2)
    }

    private var capturedView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { onCancel() }
                    .foregroundStyle(.white)
                Spacer()
                Text("确认名片")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button("确认") {
                    guard let image = viewModel.capturedImage,
                          let data = image.jpegData(compressionQuality: 0.9) else { return }
                    onPhoto(data)
                }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            }
            .padding(20)

            Spacer()
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 20)
            }
            Spacer()

            Button("重拍") { viewModel.retake() }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 26)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
            Text("无法访问相机")
                .font(.headline)
                .foregroundStyle(.white)
            Text(viewModel.errorMessage ?? "请在设置中打开相机权限")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Button("前往设置") { viewModel.openSettings() }
                .buttonStyle(.borderedProminent)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("从相册导入", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func loadImport(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { onPhoto(data) }
            }
        }
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
