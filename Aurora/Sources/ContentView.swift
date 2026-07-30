import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var tripManager: TripManager

    var body: some View {
        if tripManager.state != nil {
            ActiveTripView()
        } else {
            PlannerView()
        }
    }
}

// MARK: - Planner

struct PlannerView: View {
    @EnvironmentObject var tripManager: TripManager
    @State private var route = "A"
    @State private var from: Station?
    @State private var to: Station?
    @State private var arrivals: [TimeInterval] = []
    @State private var arrivalsTask: Task<Void, Never>?
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 40.7549, longitude: -73.984),
                           span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)))

    private var stops: [Station] { StationStore.shared.stations(on: route) }
    private var trip: Trip? {
        guard let from, let to else { return nil }
        return TripPlanner.plan(route: route, from: from, to: to)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $camera) {
                    ForEach(stops) { s in
                        Annotation(s.name, coordinate: CLLocationCoordinate2D(latitude: s.lat, longitude: s.lon)) {
                            Circle()
                                .fill(markerColor(for: s))
                                .frame(width: markerSize(for: s), height: markerSize(for: s))
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .onTapGesture { pick(s) }
                        }
                        .annotationTitles(.hidden)
                    }
                    if let trip {
                        MapPolyline(coordinates: trip.stops.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                        })
                        .stroke(RouteStyle.color(route), lineWidth: 4)
                    }
                    UserAnnotation()
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))

                controls
            }
            .navigationTitle("Aurora")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StationStore.shared.availableRoutes, id: \.self) { r in
                        Button { route = r; from = nil; to = nil } label: {
                            RouteBullet(route: r, size: 36)
                                .overlay(Circle().stroke(route == r ? Color.primary : .clear, lineWidth: 2.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            HStack {
                stationMenu(title: from?.name ?? "Board at…", system: "arrow.up.circle") { from = $0 }
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                stationMenu(title: to?.name ?? "Get off at…", system: "flag.checkered") { to = $0 }
            }
            .padding(.horizontal)

            if let trip {
                VStack(spacing: 8) {
                    BoardingCard(trip: trip, arrivals: arrivals)
                        .onAppear { watchArrivals(for: trip) }
                        .onChange(of: trip) { _, t in watchArrivals(for: t) }
                    HStack {
                        Button {
                            tripManager.start(trip)
                        } label: {
                            Label("Start Trip", systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RouteStyle.color(route))

                        Button {
                            tripManager.start(trip, demo: true)
                        } label: {
                            Label("Demo", systemImage: "play.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func stationMenu(title: String, system: String, pick: @escaping (Station) -> Void) -> some View {
        Menu {
            ForEach(stops) { s in
                Button(s.name) { pick(s) }
            }
        } label: {
            Label(title, systemImage: system)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
    }

    private func pick(_ s: Station) {
        if from == nil || (from != nil && to != nil) { from = s; to = nil }
        else if s != from { to = s }
    }

    private func markerColor(for s: Station) -> Color {
        if s == from { return .green }
        if s == to { return .red }
        return RouteStyle.color(route)
    }

    private func markerSize(for s: Station) -> CGFloat {
        (s == from || s == to) ? 18 : 10
    }

    /// Refresh live arrivals for the boarding station every 30 s.
    private func watchArrivals(for trip: Trip) {
        arrivalsTask?.cancel()
        arrivals = []
        let southbound = trip.stops[0].id < trip.stops[1].id  // track order = north->south
        arrivalsTask = Task {
            while !Task.isCancelled {
                if let a = try? await ArrivalsService.arrivals(route: trip.route,
                                                              stopId: trip.boarding.id,
                                                              southbound: southbound) {
                    await MainActor.run { arrivals = a }
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

/// Kills the wrong-side-of-the-train problem: direction, terminus, live
/// arrivals, and a first-stop sanity check before you board.
struct BoardingCard: View {
    let trip: Trip
    let arrivals: [TimeInterval]

    var body: some View {
        VStack(spacing: 6) {
            Text("\(trip.totalStops) stops • \(trip.directionLabel) toward \(trip.stops[trip.stops.count - 1].name)")
                .font(.subheadline.weight(.semibold))
            if trip.stops.count > 1 {
                Text("Right side? First stop after boarding is \(trip.stops[1].name) — if the platform sign disagrees, cross over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            if !arrivals.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                    Text("Next \(trip.route): " + arrivals.prefix(3)
                        .map { "\(max(1, Int($0 / 60))) min" }
                        .joined(separator: ", "))
                }
                .font(.caption.weight(.medium))
            }
        }
    }
}

// MARK: - Active trip

struct ActiveTripView: View {
    @EnvironmentObject var tripManager: TripManager

    var body: some View {
        guard let state = tripManager.state else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 24) {
                Spacer()
                RouteBullet(route: state.route, size: 72)

                if state.phase == .arrived {
                    Text("You're here").font(.largeTitle.bold())
                    Text(state.destination).font(.title2).foregroundStyle(.secondary)
                } else {
                    Text(state.phase == .getOffNext ? "GET OFF NEXT STOP" : "\(state.stopsRemaining) stops to go")
                        .font(.largeTitle.bold())
                        .foregroundStyle(state.phase == .getOffNext ? .orange : .primary)
                        .multilineTextAlignment(.center)
                    VStack(spacing: 4) {
                        Label("Next: \(state.nextStop)", systemImage: "arrow.forward.circle.fill")
                            .font(.title3)
                        Text("Destination: \(state.destination)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(state.totalStops - state.stopsRemaining),
                                 total: Double(max(state.totalStops, 1)))
                        .tint(RouteStyle.color(state.route))
                        .padding(.horizontal, 40)
                }

                if tripManager.demoMode {
                    Text("Demo mode").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()

                Button(role: .destructive) {
                    tripManager.end()
                } label: {
                    Label("End Trip", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        )
    }
}
