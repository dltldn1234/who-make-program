@preconcurrency import CoreMotion
import Combine
import Foundation

@MainActor
public final class HeadphoneMotionController: ObservableObject {
    @Published public private(set) var state: HeadphoneMotionState = .idle
    @Published public private(set) var pose = HeadPose(yaw: 0, pitch: 0, roll: 0)
    @Published public private(set) var lastGesture: HeadGesture?

    public var onGesture: ((HeadGesture) -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private let motionQueue: OperationQueue
    private var detector = HeadGestureDetector()

    public init() {
        motionQueue = OperationQueue()
        motionQueue.name = "com.agent.headphone-motion"
        motionQueue.qualityOfService = .userInteractive
        motionQueue.maxConcurrentOperationCount = 1
    }

    public func start() {
        guard !manager.isDeviceMotionActive else { return }

        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            state = .denied
            return
        case .notDetermined:
            state = .requestingAuthorization
        case .authorized:
            break
        @unknown default:
            state = .failed("알 수 없는 모션 권한 상태입니다.")
            return
        }

        guard manager.isDeviceMotionAvailable else {
            state = .unavailable
            return
        }

        detector.reset()
        manager.startDeviceMotionUpdates(to: motionQueue) { @Sendable [weak self] motion, error in
            let pose = motion.map {
                HeadPose(
                    yaw: $0.attitude.yaw,
                    pitch: $0.attitude.pitch,
                    roll: $0.attitude.roll
                )
            }
            let timestamp = motion?.timestamp ?? ProcessInfo.processInfo.systemUptime
            let errorMessage = error?.localizedDescription

            Task { @MainActor [weak self] in
                self?.consume(pose: pose, timestamp: timestamp, errorMessage: errorMessage)
            }
        }
        state = .tracking
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
        detector.reset()
        pose = HeadPose(yaw: 0, pitch: 0, roll: 0)
        state = .idle
    }

    public func toggle() {
        state.isTracking ? stop() : start()
    }

    private func consume(pose: HeadPose?, timestamp: TimeInterval, errorMessage: String?) {
        if let errorMessage {
            manager.stopDeviceMotionUpdates()
            state = .failed(errorMessage)
            return
        }

        guard let pose else { return }
        self.pose = pose

        if let gesture = detector.process(pose: pose, timestamp: timestamp) {
            lastGesture = gesture
            onGesture?(gesture)
        }
    }
}
