import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class DetectionViewModel {
    enum State {
        case detecting
        case detected([CGPoint])
        case failed(String)
    }

    private(set) var state: State = .detecting
    private let service: CardDetectionService

    init(service: CardDetectionService = VisionCardDetectionService()) {
        self.service = service
    }

    func detect(in image: UIImage) async {
        do {
            let result = try await service.detectCard(in: image)
            state = .detected(result.corners)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
