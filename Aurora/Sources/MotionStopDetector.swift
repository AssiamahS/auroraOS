import Foundation
import CoreMotion

/// Underground fallback: when GPS goes dark in the tunnel, a subway ride is
/// still legible in the accelerometer — sustained vibration/sway while moving,
/// near-still during the ~30 s station dwell. Each moving→dwell transition
/// after a real inter-station run counts as "we just pulled into a station".
final class MotionStopDetector {
    var onTrainStop: (() -> Void)?

    private let motion = CMMotionManager()
    private var samples: [Double] = []
    private var movingSince: Date?
    private var stillSince: Date?
    private var isMoving = false

    private let windowSize = 40            // 4 s of samples at 10 Hz
    private let movingVariance = 0.0025    // accel variance while a train runs
    private let minRunSeconds: TimeInterval = 45   // shortest believable inter-station run
    private let minDwellSeconds: TimeInterval = 8  // stillness needed to call it a stop

    func start() {
        guard motion.isAccelerometerAvailable else { return }
        samples.removeAll()
        movingSince = nil; stillSince = nil; isMoving = false
        motion.accelerometerUpdateInterval = 0.1
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            self.ingest(magnitude: sqrt(a.x * a.x + a.y * a.y + a.z * a.z))
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
    }

    private func ingest(magnitude: Double) {
        samples.append(magnitude)
        guard samples.count >= windowSize else { return }
        if samples.count > windowSize { samples.removeFirst(samples.count - windowSize) }

        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
        let now = Date()

        if variance > movingVariance {
            stillSince = nil
            if !isMoving {
                isMoving = true
                movingSince = now
            }
        } else {
            if stillSince == nil { stillSince = now }
            guard isMoving,
                  let still = stillSince, now.timeIntervalSince(still) >= minDwellSeconds,
                  let started = movingSince, still.timeIntervalSince(started) >= minRunSeconds else { return }
            isMoving = false
            movingSince = nil
            onTrainStop?()
        }
    }
}
