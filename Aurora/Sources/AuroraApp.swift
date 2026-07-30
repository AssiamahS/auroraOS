import SwiftUI

@main
struct AuroraApp: App {
    @StateObject private var tripManager = TripManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripManager)
        }
    }
}
