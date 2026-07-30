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
                .onAppear {
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("-shotOnboarding") { showOnboarding = true }
                    else if args.contains(where: { $0.hasPrefix("-shot") }) { showOnboarding = false }
                    else { showOnboarding = !onboarded }
                }
                .fullScreenCover(isPresented: $showOnboarding, onDismiss: { onboarded = true }) {
                    OnboardingView(isPresented: $showOnboarding)
                }
        }
    }
}
