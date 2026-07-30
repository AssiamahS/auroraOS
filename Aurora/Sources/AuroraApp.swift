import SwiftUI

@main
struct AuroraApp: App {
    @StateObject private var tripManager = TripManager()
    @StateObject private var store = Store()
    @AppStorage("aurora.onboarded") private var onboarded = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripManager)
                .environmentObject(store)
                .onAppear { showOnboarding = !onboarded }
                .fullScreenCover(isPresented: $showOnboarding, onDismiss: { onboarded = true }) {
                    OnboardingView(isPresented: $showOnboarding)
                }
        }
    }
}
