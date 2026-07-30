import Foundation

struct Station: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let line: String
    let borough: String
    let lat: Double
    let lon: Double
    let north: String
    let south: String
}

enum TripPhase: String, Codable {
    case riding
    case getOffNext
    case arrived
    case ended
}

/// The one payload that flows phone -> watch and phone -> Live Activity.
struct TripState: Codable, Equatable {
    var route: String
    var destination: String
    var nextStop: String
    var stopsRemaining: Int
    var totalStops: Int
    var phase: TripPhase

    var isActive: Bool { phase == .riding || phase == .getOffNext || phase == .arrived }

    func encoded() -> [String: Any] {
        [
            "route": route,
            "destination": destination,
            "nextStop": nextStop,
            "stopsRemaining": stopsRemaining,
            "totalStops": totalStops,
            "phase": phase.rawValue,
        ]
    }

    static func decode(_ dict: [String: Any]) -> TripState? {
        guard let route = dict["route"] as? String,
              let destination = dict["destination"] as? String,
              let nextStop = dict["nextStop"] as? String,
              let stopsRemaining = dict["stopsRemaining"] as? Int,
              let totalStops = dict["totalStops"] as? Int,
              let phaseRaw = dict["phase"] as? String,
              let phase = TripPhase(rawValue: phaseRaw) else { return nil }
        return TripState(route: route, destination: destination, nextStop: nextStop,
                         stopsRemaining: stopsRemaining, totalStops: totalStops, phase: phase)
    }
}
