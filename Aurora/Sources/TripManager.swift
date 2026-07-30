import Foundation
import CoreLocation
import ActivityKit
import UIKit

/// Owns the active trip: GPS progress along the line, stop countdown,
/// Live Activity (Dynamic Island), watch sync, and phone haptics.
@MainActor
final class TripManager: NSObject, ObservableObject {
    @Published var trip: Trip?
    @Published var state: TripState?
    @Published var demoMode = false

    private let locationManager = CLLocationManager()
    private var activity: Activity<TripActivityAttributes>?
    private var progressIndex = 0   // index into trip.stops we've reached so far
    private var demoTimer: Timer?

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
        publish(phase: trip.totalStops <= 1 ? .getOffNext : .riding)
        startLiveActivity()

        if demo {
            demoTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.advanceDemo() }
            }
        } else {
            locationManager.requestWhenInUseAuthorization()
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
        }
    }

    func end() {
        demoTimer?.invalidate(); demoTimer = nil
        locationManager.stopUpdatingLocation()
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

    // MARK: - Progress

    private func publishForProgress() {
        guard let trip else { return }
        let remaining = (trip.stops.count - 1) - progressIndex
        let phase: TripPhase = remaining == 0 ? .arrived : (remaining == 1 ? .getOffNext : .riding)
        publish(phase: phase)
        haptics(for: phase)
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

    private func handle(location: CLLocation) {
        guard let trip, !demoMode else { return }
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
        progressIndex = idx
        publishForProgress()
    }
}
