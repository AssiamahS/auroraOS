import Foundation
import CoreLocation

/// A planned ride: one line, board at `stops.first`, get off at `stops.last`.
struct Trip: Equatable {
    let route: String
    let stops: [Station]        // ordered from boarding to destination, inclusive
    let directionLabel: String  // "Uptown", "Downtown", "Brooklyn-bound", ...

    var boarding: Station { stops[0] }
    var destination: Station { stops[stops.count - 1] }
    var totalStops: Int { stops.count - 1 }
}

enum TripPlanner {
    /// Direct (single-line) trip between two stations on the same route.
    static func plan(route: String, from: Station, to: Station) -> Trip? {
        let line = StationStore.shared.stations(on: route)
        guard let fi = line.firstIndex(of: from), let ti = line.firstIndex(of: to), fi != ti else { return nil }
        let slice: [Station]
        let direction: String
        if fi < ti {
            slice = Array(line[fi...ti])
            direction = from.south.isEmpty ? "Southbound" : from.south
        } else {
            slice = Array(line[ti...fi]).reversed()
            direction = from.north.isEmpty ? "Northbound" : from.north
        }
        return Trip(route: route, stops: slice, directionLabel: direction)
    }

    /// All routes serving both stations directly, best (fewest stops) first.
    static func directOptions(from: Station, to: Station) -> [Trip] {
        var trips: [Trip] = []
        for route in StationStore.shared.availableRoutes {
            let line = StationStore.shared.stations(on: route)
            guard let f = line.first(where: { $0.id == from.id }) ?? line.first(where: { $0.name == from.name }),
                  let t = line.first(where: { $0.id == to.id }) ?? line.first(where: { $0.name == to.name }),
                  let trip = plan(route: route, from: f, to: t) else { continue }
            trips.append(trip)
        }
        return trips.sorted { $0.totalStops < $1.totalStops }
    }
}
