import SwiftUI

/// First-launch flow: what Aurora does, why it needs each permission, then go.
/// Explaining background location BEFORE the system prompt is what keeps both
/// users and App Review happy.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            intro.tag(0)
            permissions.tag(1)
            ready.tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    private var intro: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tram.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Never miss your stop")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Pick your line and destination. Aurora counts down the stops in the Dynamic Island and wakes you up — on your wrist — when it's time to get off. NYC Subway and NJ PATH, with live train times.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Button("Continue") { withAnimation { page = 1 } }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 60)
        }
    }

    private var permissions: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Aurora asks for three things")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 14) {
                permissionRow("location.fill", "Location — including in the background",
                              "So the stop countdown keeps running with your phone locked in your pocket. Aurora only tracks during an active trip.")
                permissionRow("bell.badge.fill", "Notifications",
                              "The \"get off now\" alert has to ring through your lock screen.")
                permissionRow("waveform.path.ecg", "Motion",
                              "The accelerometer keeps counting stations in tunnels where GPS can't see you.")
            }
            .padding(.horizontal, 28)
            Text("Nothing leaves your phone. No accounts, no tracking, no data sold — ever.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button("Continue") { withAnimation { page = 2 } }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 60)
        }
    }

    private var ready: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("You're set")
                .font(.largeTitle.bold())
            Text("Try Demo mode first — it simulates a ride so you can watch the countdown and feel the watch buzz without leaving your couch. You get \(Store.freeTripsPerWeek) tracked trips a week free.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            Button("Start riding") { isPresented = false }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 60)
        }
    }

    private func permissionRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
