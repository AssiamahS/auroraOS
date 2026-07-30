import Foundation
import WatchConnectivity
import WatchKit

/// Watch side: receives trip state from the phone and runs the arrival
/// haptic loop — repeated wrist taps once it's time to get off.
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    @Published var state: TripState?

    private var hapticTimer: Timer?
    private var arrivalTaps = 0

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(_ dict: [String: Any]) {
        guard let s = TripState.decode(dict) else { return }
        DispatchQueue.main.async {
            let previous = self.state?.phase
            self.state = s.phase == .ended ? nil : s
            self.updateHaptics(for: s.phase, changedFrom: previous)
        }
    }

    /// getOffNext -> buzz every 2.5s until arrival; arrived -> 6 strong taps, done.
    private func updateHaptics(for phase: TripPhase, changedFrom previous: TripPhase?) {
        switch phase {
        case .getOffNext:
            guard hapticTimer == nil else { break }
            WKInterfaceDevice.current().play(.notification)
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                WKInterfaceDevice.current().play(.notification)
            }
        case .arrived:
            stopTimer()
            arrivalTaps = 0
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                WKInterfaceDevice.current().play(.success)
                self?.arrivalTaps += 1
                if self?.arrivalTaps ?? 6 >= 6 { t.invalidate(); self?.hapticTimer = nil }
            }
        case .riding:
            stopTimer()
            if previous == nil { WKInterfaceDevice.current().play(.start) }
        case .ended:
            stopTimer()
        }
    }

    private func stopTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Pick up a trip that started before the watch app launched.
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { apply(ctx) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }
}
