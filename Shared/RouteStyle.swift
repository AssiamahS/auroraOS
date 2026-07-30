import SwiftUI

/// Official MTA line colors, keyed by route.
enum RouteStyle {
    static func color(_ route: String) -> Color {
        switch route {
        case "1", "2", "3": return Color(red: 0.93, green: 0.20, blue: 0.20)      // IRT red
        case "4", "5", "6": return Color(red: 0.00, green: 0.58, blue: 0.24)      // IRT green
        case "7":           return Color(red: 0.72, green: 0.23, blue: 0.67)      // Flushing purple
        case "A", "C", "E": return Color(red: 0.00, green: 0.22, blue: 0.65)      // IND blue
        case "B", "D", "F", "M": return Color(red: 1.00, green: 0.39, blue: 0.10) // 6th Av orange
        case "G":           return Color(red: 0.42, green: 0.75, blue: 0.27)      // Crosstown lime
        case "J", "Z":      return Color(red: 0.60, green: 0.40, blue: 0.22)      // Nassau brown
        case "L":           return Color(red: 0.65, green: 0.66, blue: 0.67)      // Canarsie gray
        case "N", "Q", "R", "W": return Color(red: 0.99, green: 0.80, blue: 0.04) // Broadway yellow
        case "S", "SIR":    return Color(red: 0.50, green: 0.51, blue: 0.51)      // Shuttle gray
        case "P1":          return Color(red: 0.85, green: 0.23, blue: 0.19)      // PATH NWK-WTC red
        case "P2":          return Color(red: 0.30, green: 0.69, blue: 0.31)      // PATH HOB-WTC green
        case "P3":          return Color(red: 0.94, green: 0.82, blue: 0.11)      // PATH JSQ-33 yellow
        case "P4":          return Color(red: 0.26, green: 0.52, blue: 0.96)      // PATH HOB-33 blue
        default:            return .gray
        }
    }

    /// Yellow bullets need dark text; everything else white.
    static func textColor(_ route: String) -> Color {
        switch route {
        case "N", "Q", "R", "W", "P3": return .black
        default: return .white
        }
    }

    static func isPATH(_ route: String) -> Bool {
        route.hasPrefix("P") && route.count == 2
    }

    /// Long name for PATH lines (subway routes are their own name).
    static func displayName(_ route: String) -> String {
        switch route {
        case "P1": return "PATH Newark–WTC"
        case "P2": return "PATH Hoboken–WTC"
        case "P3": return "PATH JSQ–33 St"
        case "P4": return "PATH Hoboken–33 St"
        default: return route
        }
    }
}

struct RouteBullet: View {
    let route: String
    var size: CGFloat = 32

    var body: some View {
        Text(route)
            .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .foregroundStyle(RouteStyle.textColor(route))
            .frame(width: size, height: size)
            .background(Circle().fill(RouteStyle.color(route)))
    }
}
