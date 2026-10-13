import AVFoundation
import Photos

enum PermissionStatus: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

protocol PermissionService {
    func cameraStatus() -> PermissionStatus
    func photoLibraryStatus() -> PermissionStatus
    func requestCamera() async -> PermissionStatus
    func requestPhotoLibrary() async -> PermissionStatus
}

/// 系统权限实现。
/// 读取相册走 PhotosPicker，不需要权限；这里的 photoLibrary 特指“把图片写入相册”的 addOnly 权限。
struct SystemPermissionService: PermissionService {
    func cameraStatus() -> PermissionStatus {
        map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func photoLibraryStatus() -> PermissionStatus {
        map(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    func requestCamera() async -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else { return map(status) }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }

    func requestPhotoLibrary() async -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .notDetermined else { return map(status) }
        let next = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return map(next)
    }

    private func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    private func map(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized, .limited: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}
