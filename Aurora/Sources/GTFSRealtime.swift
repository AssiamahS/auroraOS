import Foundation

/// Minimal protobuf wire-format reader — just enough to walk a GTFS-Realtime
/// FeedMessage without pulling in SwiftProtobuf. Verified against the live
/// MTA feed (field numbers from gtfs-realtime.proto + NYCT extensions).
struct ProtoReader {
    enum Value {
        case varint(UInt64)
        case bytes(Data)
    }

    static func fields(_ data: Data) -> [(Int, Value)] {
        var out: [(Int, Value)] = []
        var i = data.startIndex
        func varint() -> UInt64? {
            var x: UInt64 = 0, s: UInt64 = 0
            while i < data.endIndex {
                let c = data[i]; i = data.index(after: i)
                x |= UInt64(c & 0x7f) << s
                if c & 0x80 == 0 { return x }
                s += 7
                if s > 63 { return nil }
            }
            return nil
        }
        while i < data.endIndex {
            guard let key = varint() else { return out }
            let field = Int(key >> 3)
            switch key & 7 {
            case 0:
                guard let v = varint() else { return out }
                out.append((field, .varint(v)))
            case 2:
                guard let len = varint(),
                      let end = data.index(i, offsetBy: Int(len), limitedBy: data.endIndex) else { return out }
                out.append((field, .bytes(data[i..<end])))
                i = end
            case 5:
                guard let end = data.index(i, offsetBy: 4, limitedBy: data.endIndex) else { return out }
                i = end
            case 1:
                guard let end = data.index(i, offsetBy: 8, limitedBy: data.endIndex) else { return out }
                i = end
            default:
                return out  // unknown wire type: bail rather than misparse
            }
        }
        return out
    }
}

/// Live arrivals from the MTA's free GTFS-Realtime feeds (no API key).
enum ArrivalsService {
    private static let base = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"

    /// Which feed carries which routes.
    static func feedURL(for route: String) -> URL? {
        let suffix: String
        switch route {
        case "1", "2", "3", "4", "5", "6", "7", "S": suffix = ""
        case "A", "C", "E": suffix = "-ace"
        case "B", "D", "F", "M": suffix = "-bdfm"
        case "G": suffix = "-g"
        case "J", "Z": suffix = "-jz"
        case "N", "Q", "R", "W": suffix = "-nqrw"
        case "L": suffix = "-l"
        case "SIR": suffix = "-si"
        default: return nil
        }
        return URL(string: base + suffix)
    }

    /// Upcoming arrivals (seconds from now) for `route` at GTFS stop `stopId`
    /// heading `southbound` or not. Stop IDs in the RT feed carry an N/S suffix.
    static func arrivals(route: String, stopId: String, southbound: Bool) async throws -> [TimeInterval] {
        guard let url = feedURL(for: route) else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        let target = stopId + (southbound ? "S" : "N")
        let now = Date().timeIntervalSince1970
        var result: [TimeInterval] = []

        for case let (2, .bytes(entity)) in ProtoReader.fields(data) {                 // FeedEntity
            for case let (3, .bytes(tripUpdate)) in ProtoReader.fields(entity) {       // TripUpdate
                var routeId: String?
                var stopTimeUpdates: [Data] = []
                for (f, v) in ProtoReader.fields(tripUpdate) {
                    if f == 1, case let .bytes(trip) = v {                             // TripDescriptor
                        for case let (5, .bytes(r)) in ProtoReader.fields(trip) {
                            routeId = String(data: r, encoding: .utf8)
                        }
                    } else if f == 2, case let .bytes(stu) = v {
                        stopTimeUpdates.append(stu)
                    }
                }
                guard routeId == route else { continue }
                for stu in stopTimeUpdates {                                           // StopTimeUpdate
                    var stop: String?
                    var arrival: Double?
                    for (f, v) in ProtoReader.fields(stu) {
                        if f == 4, case let .bytes(s) = v { stop = String(data: s, encoding: .utf8) }
                        if f == 2, case let .bytes(ev) = v {                           // arrival StopTimeEvent
                            // time = field 2, plain int64 varint
                            for case let (2, .varint(t)) in ProtoReader.fields(ev) {
                                arrival = Double(Int64(bitPattern: t))
                            }
                        }
                    }
                    if stop == target, let a = arrival, a > now {
                        result.append(a - now)
                    }
                }
            }
        }
        return result.sorted()
    }
}
