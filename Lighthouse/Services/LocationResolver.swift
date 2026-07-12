import Foundation

struct GeoLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var address: String?
    var countryCode: String?
    var countryName: String?
    var accuracyMeters: Double?
    var timestamp: Date = .now

    func formatCoordinates() -> String {
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"
        return String(
            format: "%.4f°%@, %.4f°%@",
            abs(latitude), latDir,
            abs(longitude), lonDir
        )
    }

    func shortLabel() -> String { address ?? formatCoordinates() }
    func countryLabel() -> String { countryName ?? countryCode ?? "Unknown region" }
}

struct ResolvedLocation: Equatable {
    var displayName: String
    var latitude: Double?
    var longitude: Double?
    var source: String = "reported"
}

enum LocationResolver {
    private static let unknownLabels: Set<String> = [
        "unknown", "unknown location", "unknown road"
    ]

    static func resolve(reportedLocation: String?, geo: GeoLocation?) -> ResolvedLocation {
        let reported = reportedLocation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let hasReported = reported.map { !unknownLabels.contains($0.lowercased()) } ?? false

        let displayName: String
        if hasReported, let reported, let geo {
            displayName = "\(reported) (GPS: \(geo.formatCoordinates()))"
        } else if hasReported, let reported {
            displayName = reported
        } else if let address = geo?.address {
            displayName = address
        } else if let geo {
            displayName = geo.formatCoordinates()
        } else {
            displayName = reported ?? "Unknown location"
        }

        let source: String
        if hasReported && geo != nil {
            source = "reported+gps"
        } else if geo != nil {
            source = "gps"
        } else {
            source = "reported"
        }

        return ResolvedLocation(
            displayName: displayName,
            latitude: geo?.latitude,
            longitude: geo?.longitude,
            source: source
        )
    }

    static func distanceKm(from a: GeoLocation, toLat: Double, toLon: Double) -> Double {
        haversineKm(lat1: a.latitude, lon1: a.longitude, lat2: toLat, lon2: toLon)
    }

    static func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
