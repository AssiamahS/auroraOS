import SwiftUI

@main
struct AuroraWatchApp: App {
    @StateObject private var session = WatchSession.shared

    var body: some Scene {
        WindowGroup {
            WatchTripView()
                .environmentObject(session)
        }
    }
}
