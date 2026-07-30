import SwiftUI

struct WatchTripView: View {
    @EnvironmentObject var session: WatchSession

    var body: some View {
        if let state = session.state {
            tripBody(state)
        } else {
            idleBody
        }
    }

    private var idleBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No active trip")
                .font(.headline)
            Text("Start one on your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func tripBody(_ state: TripState) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                RouteBullet(route: state.route, size: 26)
                Text(state.destination)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            switch state.phase {
            case .arrived:
                Text("YOU'RE HERE")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                Text(state.destination)
                    .font(.caption)
            case .getOffNext:
                Text("GET OFF")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
                Text("next stop: \(state.nextStop)")
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            default:
                Text("\(state.stopsRemaining)")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(RouteStyle.color(state.route))
                Text(state.stopsRemaining == 1 ? "stop to go" : "stops to go")
                    .font(.caption)
                Text("next: \(state.nextStop)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: Double(state.totalStops - state.stopsRemaining),
                         total: Double(max(state.totalStops, 1)))
                .tint(RouteStyle.color(state.route))
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
    }
}
