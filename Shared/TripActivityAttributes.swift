import Foundation
import ActivityKit

struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextStop: String
        var stopsRemaining: Int
        var totalStops: Int
        var phase: String   // TripPhase rawValue — ActivityKit payloads stay flat
    }

    var route: String
    var destination: String
}
