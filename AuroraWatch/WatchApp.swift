import SwiftUI

@main
struct AuroraWatchApp: App {
    @StateObject private var session = WatchSession.shared

    var body: some Scene {
        WindowGroup {
            WatchTripView()
                .environmentObject(session)
                .onAppear {
                    // marketing-screenshot mode for the CI simulator rig
                    if ProcessInfo.processInfo.arguments.contains("-shotTrip") {
                        session.state = TripState(route: "A", destination: "Hoyt-Schermerhorn Sts",
                                                  nextStop: "Fulton St", stopsRemaining: 4,
                                                  totalStops: 8, phase: .riding)
                    }
                }
        }
    }
}
