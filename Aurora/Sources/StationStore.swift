import Foundation
import CoreLocation

/// Loads the bundled MTA station data: route -> stations in track order.
final class StationStore {
    static let shared = StationStore()

    /// Route ID ("A", "6", ...) -> stations ordered north to south along the line.
    let routes: [String: [Station]]

    /// Routes worth showing in the picker, in NYC-conventional order.
    static let displayOrder = ["1", "2", "3", "4", "5", "6", "7",
                               "A", "C", "E", "B", "D", "F", "M",
                               "G", "J", "Z", "L", "N", "Q", "R", "W", "S", "SIR"]

    private init() {
        guard let url = Bundle.main.url(forResource: "Stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Station]].self, from: data) else {
            routes = [:]
            assertionFailure("Stations.json missing or malformed")
            return
        }
        routes = decoded
    }

    var availableRoutes: [String] {
        Self.displayOrder.filter { routes[$0]?.isEmpty == false }
    }

    func stations(on route: String) -> [Station] {
        routes[route] ?? []
    }

    /// Nearest station on a route to a coordinate, with its index in track order.
    func nearestStation(on route: String, to coord: CLLocationCoordinate2D) -> (station: Station, index: Int, distance: CLLocationDistance)? {
        let stops = stations(on: route)
        guard !stops.isEmpty else { return nil }
        let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var best: (Station, Int, CLLocationDistance)?
        for (i, s) in stops.enumerated() {
            let d = here.distance(from: CLLocation(latitude: s.lat, longitude: s.lon))
            if best == nil || d < best!.2 { best = (s, i, d) }
        }
        return best.map { (station: $0.0, index: $0.1, distance: $0.2) }
    }
}
