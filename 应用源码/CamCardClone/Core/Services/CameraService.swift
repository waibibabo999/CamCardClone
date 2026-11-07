import AVFoundation

protocol CameraService {
    var session: AVCaptureSession { get }
    func startSession() throws
    func stopSession()
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void)
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer
}

enum CameraServiceError: LocalizedError {
    case noCamera
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "未检测到后置摄像头"
        case .captureFailed:
            return "拍摄失败，请重试"
        }
    }
}

/// 基于 AVFoundation 的后置相机实现。配置只在第一次 startSession 时完成。
final class AVCameraService: NSObject, CameraService, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var pendingCompletion: ((Result<Data, Error>) -> Void)?
    private var isConfigured = false

    func startSession() throws {
        if isConfigured {
            if !session.isRunning { session.startRunning() }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw CameraServiceError.noCamera
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) {
                photoOutput.isLivePhotoCaptureEnabled = false
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()
        } catch {
            session.commitConfiguration()
            throw error
        }

        isConfigured = true
        session.startRunning()
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        pendingCompletion = completion
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: Result<Data, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(CameraServiceError.captureFailed)
        }
        pendingCompletion?(result)
        pendingCompletion = nil
    }
}
