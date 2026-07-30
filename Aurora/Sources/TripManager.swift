import Foundation
import CoreLocation
import ActivityKit
import UserNotifications
import UIKit

/// Owns the active trip: GPS progress along the line, geofence wake-up at the
/// destination, accelerometer stop-counting in tunnels, the stop countdown,
/// Live Activity (Dynamic Island), watch sync, and phone haptics.
@MainActor
final class TripManager: NSObject, ObservableObject {
    @Published var trip: Trip?
    @Published var state: TripState?
    @Published var demoMode = false

    private let locationManager = CLLocationManager()
    private let motionDetector = MotionStopDetector()
    private var activity: Activity<TripActivityAttributes>?
    private var progressIndex = 0        // index into trip.stops we've reached so far
    private var lastGPSFix = Date.distantPast
    private var demoTimer: Timer?

    private static let destRegionID = "aurora.dest"
    private static let penultRegionID = "aurora.penult"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .otherNavigation
        PhoneSession.shared.activate()
    }

    // MARK: - Trip lifecycle

    func start(_ trip: Trip, demo: Bool = false) {
        self.trip = trip
        demoMode = demo
        progressIndex = 0
        lastGPSFix = .distantPast
        publish(phase: trip.totalStops <= 1 ? .getOffNext : .riding)
        startLiveActivity()

        if demo {
            demoTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.advanceDemo() }
            }
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        // Always-auth so geofence entry can wake the app with the phone locked.
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
        registerGeofences(for: trip)
        // Accelerometer keeps the count honest where GPS dies in the tunnel.
        motionDetector.onTrainStop = { [weak self] in
            Task { @MainActor in self?.handleInferredStop() }
        }
        motionDetector.start()
    }

    func end() {
        demoTimer?.invalidate(); demoTimer = nil
        motionDetector.stop()
        locationManager.stopUpdatingLocation()
        clearGeofences()
        if let trip {
            let final = TripState(route: trip.route, destination: trip.destination.name,
                                  nextStop: trip.destination.name, stopsRemaining: 0,
                                  totalStops: trip.totalStops, phase: .ended)
            PhoneSession.shared.send(final)
        }
        endLiveActivity()
        trip = nil
        state = nil
    }

    private func advanceDemo() {
        guard let trip else { return }
        guard progressIndex < trip.stops.count - 1 else { end(); return }
        progressIndex += 1
        publishForProgress()
    }

    // MARK: - Geofences (wakes the app at the destination even if suspended)

    private func registerGeofences(for trip: Trip) {
        clearGeofences()
        let dest = trip.destination
        let destRegion = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: dest.lat, longitude: dest.lon),
            radius: 400, identifier: Self.destRegionID)
        destRegion.notifyOnEntry = true
        destRegion.notifyOnExit = false
        locationManager.startMonitoring(for: destRegion)

        if trip.stops.count >= 2 {
            let penult = trip.stops[trip.stops.count - 2]
            let penultRegion = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: penult.lat, longitude: penult.lon),
                radius: 400, identifier: Self.penultRegionID)
            penultRegion.notifyOnEntry = true
            penultRegion.notifyOnExit = false
            locationManager.startMonitoring(for: penultRegion)
        }
    }

    private func clearGeofences() {
        for region in locationManager.monitoredRegions
        where region.identifier == Self.destRegionID || region.identifier == Self.penultRegionID {
            locationManager.stopMonitoring(for: region)
        }
    }

    // MARK: - Progress

    private func setProgress(_ index: Int) {
        guard let trip, index > progressIndex else { return }
        progressIndex = min(index, trip.stops.count - 1)
        publishForProgress()
    }

    /// Accelerometer said "we just pulled into a station" and GPS hasn't had a
    /// fix recently. Inference alone may advance to the penultimate stop but
    /// never declare arrival — that needs GPS or the geofence.
    private func handleInferredStop() {
        guard let trip, !demoMode else { return }
        guard Date().timeIntervalSince(lastGPSFix) > 120 else { return }
        guard progressIndex < trip.stops.count - 2 else { return }
        setProgress(progressIndex + 1)
    }

    private func publishForProgress() {
        guard let trip else { return }
        let remaining = (trip.stops.count - 1) - progressIndex
        let phase: TripPhase = remaining == 0 ? .arrived : (remaining == 1 ? .getOffNext : .riding)
        publish(phase: phase)
        haptics(for: phase)
        notify(for: phase)
        if phase == .arrived {
            // Leave the arrival state visible briefly, then tear down.
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                if self?.state?.phase == .arrived { self?.end() }
            }
        }
    }

    private func publish(phase: TripPhase) {
        guard let trip else { return }
        let remaining = (trip.stops.count - 1) - progressIndex
        let nextIdx = min(progressIndex + 1, trip.stops.count - 1)
        let s = TripState(route: trip.route,
                          destination: trip.destination.name,
                          nextStop: trip.stops[nextIdx].name,
                          stopsRemaining: remaining,
                          totalStops: trip.totalStops,
                          phase: phase)
        state = s
        PhoneSession.shared.send(s)
        updateLiveActivity(s)
    }

    private func haptics(for phase: TripPhase) {
        switch phase {
        case .getOffNext: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .arrived: UINotificationFeedbackGenerator().notificationOccurred(.success)
        default: break
        }
    }

    /// Time-sensitive local notification so the phone rings through even when
    /// the app is in the background (the geofence path relies on this).
    private func notify(for phase: TripPhase) {
        guard let trip, !demoMode else { return }
        let content = UNMutableNotificationContent()
        switch phase {
        case .getOffNext:
            content.title = "Get off at the next stop"
            content.body = "\(trip.destination.name) is next — \(trip.route) train."
        case .arrived:
            content.title = "This is your stop"
            content.body = "You've reached \(trip.destination.name). Get off now."
        default:
            return
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "aurora.\(phase.rawValue)", content: content, trigger: nil))
    }

    // MARK: - Live Activity (Dynamic Island)

    private func startLiveActivity() {
        guard let trip, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = TripActivityAttributes(route: trip.route, destination: trip.destination.name)
        let content = ActivityContent(state: contentState(), staleDate: nil)
        activity = try? Activity.request(attributes: attrs, content: content)
    }

    private func updateLiveActivity(_ s: TripState) {
        guard let activity else { return }
        let content = ActivityContent(state: contentState(), staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endLiveActivity() {
        guard let activity else { return }
        let content = ActivityContent(state: contentState(), staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    private func contentState() -> TripActivityAttributes.ContentState {
        let s = state
        return TripActivityAttributes.ContentState(nextStop: s?.nextStop ?? "",
                                                   stopsRemaining: s?.stopsRemaining ?? 0,
                                                   totalStops: s?.totalStops ?? 0,
                                                   phase: (s?.phase ?? .ended).rawValue)
    }
}

// MARK: - CLLocationManagerDelegate

extension TripManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.handle(location: loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleRegionEntry(id) }
    }

    private func handleRegionEntry(_ identifier: String) {
        guard let trip, !demoMode else { return }
        switch identifier {
        case Self.destRegionID: setProgress(trip.stops.count - 1)
        case Self.penultRegionID: setProgress(trip.stops.count - 2)
        default: break
        }
    }

    private func handle(location: CLLocation) {
        guard let trip, !demoMode else { return }
        lastGPSFix = Date()
        // Nearest stop on OUR trip segment, ahead of (or at) current progress.
        var bestIdx: Int?
        var bestDist = CLLocationDistance.greatestFiniteMagnitude
        for (i, s) in trip.stops.enumerated() where i >= progressIndex {
            let d = location.distance(from: CLLocation(latitude: s.lat, longitude: s.lon))
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        // Only advance once we're actually near a station (subway GPS is spotty
        // underground; fixes usually land at stations / above-ground stretches).
        guard let idx = bestIdx, bestDist < 450, idx > progressIndex else { return }
        setProgress(idx)
    }
}
