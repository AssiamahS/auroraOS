import Foundation
import WatchConnectivity

/// Phone side of the watch link. applicationContext carries the latest trip
/// state (survives the watch app being closed); sendMessage gives the
/// low-latency path when the watch is reachable.
final class PhoneSession: NSObject, WCSessionDelegate {
    static let shared = PhoneSession()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ state: TripState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let payload = state.encoded()
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
