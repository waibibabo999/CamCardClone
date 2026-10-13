import AVFoundation
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class CaptureViewModel {
    enum Screen {
        case loading
        case ready
        case permissionDenied
        case captured
    }

    private(set) var screen: Screen = .loading
    private(set) var capturedImage: UIImage?
    var errorMessage: String?

    var session: AVCaptureSession { cameraService.session }

    private let permissionService: PermissionService
    private let cameraService: CameraService

    init(permissionService: PermissionService = SystemPermissionService(),
         cameraService: CameraService = AVCameraService()) {
        self.permissionService = permissionService
        self.cameraService = cameraService
    }

    func prepare() async {
        let status = await permissionService.requestCamera()
        guard status == .authorized else {
            screen = .permissionDenied
            return
        }
        do {
            try cameraService.startSession()
            screen = .ready
        } catch {
            errorMessage = error.localizedDescription
            screen = .permissionDenied
        }
    }

    func capture() {
        cameraService.capturePhoto { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let data):
                    self.capturedImage = UIImage(data: data)
                    self.screen = .captured
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func retake() {
        capturedImage = nil
        screen = .ready
    }

    func stop() {
        cameraService.stopSession()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
