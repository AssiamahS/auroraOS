import WidgetKit
import SwiftUI
import ActivityKit

@main
struct AuroraWidgetBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivity()
    }
}

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // Lock screen banner
            LockScreenTripView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    bullet(context.attributes.route, size: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(context.state.stopsRemaining)")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(getOff(context) ? .orange : .white)
                        Text(context.state.stopsRemaining == 1 ? "stop" : "stops")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(getOff(context) ? "GET OFF NEXT STOP" : "Next: \(context.state.nextStop)")
                            .font(.headline)
                            .foregroundStyle(getOff(context) ? .orange : .white)
                            .lineLimit(1)
                        Text("to \(context.attributes.destination)")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: progress(context))
                        .tint(RouteStyle.color(context.attributes.route))
                        .padding(.horizontal, 8)
                }
            } compactLeading: {
                bullet(context.attributes.route, size: 22)
            } compactTrailing: {
                Text("\(context.state.stopsRemaining)")
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(getOff(context) ? .orange : .white)
            } minimal: {
                Text("\(context.state.stopsRemaining)")
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(getOff(context) ? .orange : RouteStyle.color(context.attributes.route))
            }
        }
    }

    private func getOff(_ context: ActivityViewContext<TripActivityAttributes>) -> Bool {
        context.state.phase == "getOffNext" || context.state.phase == "arrived"
    }

    private func progress(_ context: ActivityViewContext<TripActivityAttributes>) -> Double {
        let total = max(context.state.totalStops, 1)
        return Double(total - context.state.stopsRemaining) / Double(total)
    }

    private func bullet(_ route: String, size: CGFloat) -> some View {
        Text(route)
            .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .foregroundStyle(RouteStyle.textColor(route))
            .frame(width: size, height: size)
            .background(Circle().fill(RouteStyle.color(route)))
    }
}

struct LockScreenTripView: View {
    let context: ActivityViewContext<TripActivityAttributes>

    private var getOff: Bool {
        context.state.phase == "getOffNext" || context.state.phase == "arrived"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(context.attributes.route)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(RouteStyle.textColor(context.attributes.route))
                .frame(width: 40, height: 40)
                .background(Circle().fill(RouteStyle.color(context.attributes.route)))
            VStack(alignment: .leading, spacing: 2) {
                Text(getOff ? "GET OFF NEXT STOP" : "Next: \(context.state.nextStop)")
                    .font(.headline)
                    .foregroundStyle(getOff ? .orange : .white)
                Text("to \(context.attributes.destination)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(context.state.stopsRemaining)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(getOff ? .orange : .white)
                Text(context.state.stopsRemaining == 1 ? "stop" : "stops")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
