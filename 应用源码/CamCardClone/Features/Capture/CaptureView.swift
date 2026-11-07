import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct CaptureView: View {
    let backOnly: Bool
    let frameInstruction: String?
    let onPhoto: (UIImage, CGRect?) -> Void
    let onCancel: () -> Void

    @State private var viewModel: CaptureViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var recognitionMode: RecognitionMode = .basic
    @State private var captureMode: CaptureMode = .single
    @State private var centeredMode: CaptureMode? = .single
    @State private var modeNotice: String?
    @State private var notice: String?
    @State private var isCapturing = false
    @State private var cameraGeometrySize: CGSize = .zero
    @State private var guideFrameRect: CGRect = .zero

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
    init(
        backOnly: Bool = false,
        frameInstruction: String? = nil,
        onPhoto: @escaping (UIImage, CGRect?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.backOnly = backOnly
        self.frameInstruction = frameInstruction
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
                cameraScreen
            default:
                cameraScreen
            }
        }
        .task { await viewModel.prepare() }
        .onDisappear { viewModel.stop() }
        .onChange(of: viewModel.screen) { _, screen in
            if screen == .captured {
                submitCapturedPhoto()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            guard let message else { return }
            isCapturing = false
            notice = message
        }
        .onChange(of: pickerItem) { _, item in
            loadImport(item)
        }
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
            let frameWidth = geometry.size.width * 0.88
            let frameHeight = min(frameWidth * 1.68, geometry.size.height * 0.65)
            let frameRect = CGRect(
                x: (geometry.size.width - frameWidth) / 2,
                y: geometry.size.height * 0.42 - frameHeight / 2,
                width: frameWidth,
                height: frameHeight
            )

            ZStack {
                Color.black.ignoresSafeArea()
                CameraPreviewView(session: viewModel.session)
                    .ignoresSafeArea()

                ScanMask(frameRect: frameRect)
                scanFrame(frameRect: frameRect)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 0)
                        .padding(.bottom, 2)
                        .background(Color.black.ignoresSafeArea(edges: .top))

                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        if !backOnly {
                            captureModeBar
                        }
                        if backOnly {
                            backCaptureControls
                        } else {
                            captureControls
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 54)
                    .background(Color.black.ignoresSafeArea(edges: .bottom))
                }
            }
            .onAppear {
                updateGuideGeometry(size: geometry.size, frameRect: frameRect)
            }
            .onChange(of: geometry.size) { _, size in
                updateGuideGeometry(size: size, frameRect: frameRect)
            }

            if viewModel.screen == .loading || isCapturing {
                captureTransitionOverlay
            }
        }
    }

    private var captureTransitionOverlay: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text(
                    isCapturing
                        ? (backOnly ? "正在处理照片…" : "正在扫描名片…")
                        : "正在打开相机…"
                )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color.black.opacity(0.66))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func scanFrame(frameRect: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.95), lineWidth: 2)
                .frame(width: frameRect.width, height: frameRect.height)
                .position(x: frameRect.midX, y: frameRect.midY)

            Text(frameInstruction ?? (backOnly ? "请将名片背面放入框内" : "请将镜头靠近名片"))
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .position(x: frameRect.midX, y: frameRect.minY + 28)

            if !backOnly {
                Label("轻触照亮", systemImage: "flashlight.on.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .position(x: frameRect.midX, y: frameRect.maxY - 30)
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if backOnly {
            HStack {
                closeButton
                Spacer()
            }
            .frame(height: 38)
        } else {
            HStack(spacing: 12) {
                closeButton

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
                    notice = "更多识别设置暂未开放。"
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
            }
            .frame(height: 38)
        }
    }

    private var closeButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("关闭")
        .accessibilityIdentifier("closeScanButton")
    }

    private var shutterButton: some View {
        Button {
            guard !isCapturing else { return }
            viewModel.errorMessage = nil
            isCapturing = true
            viewModel.capture()
        } label: {
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 6)
                .frame(width: 82, height: 82)
                .overlay(Circle().fill(.white).padding(9))
        }
        .disabled(viewModel.screen != .ready || isCapturing)
        .accessibilityLabel("拍摄")
        .accessibilityIdentifier("captureButton")
    }

    private var backCaptureControls: some View {
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
            shutterButton
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
    }

    private func recognitionButton(_ mode: RecognitionMode, title: String) -> some View {
        Button {
            recognitionMode = mode
        } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(recognitionMode == mode ? .black : .white)
                .padding(.horizontal, 20)
                .frame(height: 27)
                .background(recognitionMode == mode ? Color.white : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
                ScrollViewReader { proxy in
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
                                    VStack(spacing: 5) {
                                        Rectangle()
                                            .fill(captureMode == mode ? Color.blue : Color.clear)
                                            .frame(width: 48, height: 2)
                                        Text(mode.rawValue)
                                            .font(.footnote.weight(captureMode == mode ? .semibold : .regular))
                                            .foregroundStyle(captureMode == mode ? .white : .white.opacity(0.65))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(width: 68)
                                }
                                .buttonStyle(.plain)
                                .id(mode)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .rotation3DEffect(
                                            .degrees(phase.isIdentity ? 0 : (phase.value < 0 ? 18.0 : -18.0)),
                                            axis: (x: 0, y: 1, z: 0),
                                            perspective: 0.55
                                        )
                                        .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                        .opacity(phase.isIdentity ? 1 : 0.7)
                                }
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
                    .onAppear {
                        // ScrollPosition does not always resolve on the first layout pass.
                        DispatchQueue.main.async {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                proxy.scrollTo(CaptureMode.single, anchor: .center)
                            }
                        }
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
        modeNotice = "\(mode.rawValue)暂未开放"
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

            shutterButton

            Spacer()

            Button {
                notice = "多张拍摄暂未开放。"
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
        .padding(.horizontal, 24)
        .padding(.top, 2)
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
        isCapturing = true
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    isCapturing = false
                    notice = "无法读取所选照片"
                }
                return
            }
            let image = await Task.detached(priority: .userInitiated) {
                UIImage.cardScanImage(from: data)
            }.value
            await MainActor.run {
                guard let image else {
                    isCapturing = false
                    notice = "照片处理失败，请重试"
                    return
                }
                onPhoto(image, nil)
            }
        }
    }

    private func submitCapturedPhoto() {
        guard let image = viewModel.capturedImage else {
            isCapturing = false
            notice = "照片处理失败，请重拍"
            viewModel.retake()
            return
        }
        onPhoto(image, normalizedGuideCrop(for: image))
    }

    private func updateGuideGeometry(size: CGSize, frameRect: CGRect) {
        cameraGeometrySize = size
        guideFrameRect = frameRect
    }

    private func normalizedGuideCrop(for image: UIImage) -> CGRect? {
        guard cameraGeometrySize.width > 0,
              cameraGeometrySize.height > 0,
              guideFrameRect.width > 0,
              guideFrameRect.height > 0,
              image.size.width > 0,
              image.size.height > 0 else {
            return nil
        }

        // AVCaptureVideoPreviewLayer uses aspect-fill. Convert the visible guide
        // rectangle back into the captured image's pixel coordinate space.
        let fillScale = max(
            cameraGeometrySize.width / image.size.width,
            cameraGeometrySize.height / image.size.height
        )
        let renderedSize = CGSize(
            width: image.size.width * fillScale,
            height: image.size.height * fillScale
        )
        let offset = CGPoint(
            x: (cameraGeometrySize.width - renderedSize.width) / 2,
            y: (cameraGeometrySize.height - renderedSize.height) / 2
        )
        let imagePoint = CGPoint(
            x: (guideFrameRect.minX - offset.x) / fillScale,
            y: (guideFrameRect.minY - offset.y) / fillScale
        )
        let normalized = CGRect(
            x: imagePoint.x / image.size.width,
            y: imagePoint.y / image.size.height,
            width: guideFrameRect.width / fillScale / image.size.width,
            height: guideFrameRect.height / fillScale / image.size.height
        )
        let margin = min(normalized.width, normalized.height) * 0.025
        return normalized.insetBy(dx: -margin, dy: -margin)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
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

private struct ScanMask: View {
    let frameRect: CGRect

    var body: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRoundedRect(in: frameRect, cornerSize: CGSize(width: 2, height: 2))
            context.fill(
                path,
                with: .color(.black.opacity(0.28)),
                style: FillStyle(eoFill: true)
            )
        }
        .allowsHitTesting(false)
    }
}
