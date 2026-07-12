import Foundation

enum EmergencyAgent: String, CaseIterable, Identifiable, Codable {
    case ambulance
    case police
    case fire
    case naturalDisaster
    case childCare

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ambulance: return "Ambulance"
        case .police: return "Police"
        case .fire: return "Fire & Rescue"
        case .naturalDisaster: return "Disaster Response"
        case .childCare: return "Child Protection"
        }
    }

    var resourceType: String {
        switch self {
        case .ambulance: return "ambulance"
        case .police: return "police"
        case .fire: return "fire"
        case .naturalDisaster: return "disaster"
        case .childCare: return "childcare"
        }
    }

    var summary: String {
        switch self {
        case .ambulance: return "Medical emergencies, injuries, illness"
        case .police: return "Crime, violence, threats, public safety"
        case .fire: return "Fire, smoke, gas leaks, building collapse"
        case .naturalDisaster: return "Floods, earthquakes, storms, wildfires"
        case .childCare: return "Children missing, hurt, or in danger"
        }
    }

    var systemImage: String {
        switch self {
        case .ambulance: return "cross.case.fill"
        case .police: return "shield.checkered"
        case .fire: return "flame.fill"
        case .naturalDisaster: return "tornado"
        case .childCare: return "figure.and.child.holdinghands"
        }
    }

    var keywords: [String] {
        switch self {
        case .ambulance:
            ["ambulance", "medical", "injured", "hurt", "bleeding", "unconscious",
             "heart attack", "stroke", "can't breathe", "pregnant", "overdose", "sick"]
        case .police:
            ["police", "crime", "robbery", "attack", "assault", "shooting", "stabbing",
             "violence", "threat", "intruder", "kidnap", "abuse", "gun", "weapon"]
        case .fire:
            ["fire", "smoke", "burning", "explosion", "gas leak", "collapsed",
             "building fell", "trapped", "rescue", "flames"]
        case .naturalDisaster:
            ["flood", "earthquake", "tsunami", "cyclone", "hurricane", "tornado",
             "landslide", "storm", "wildfire", "disaster", "evacuate", "dam burst"]
        case .childCare:
            ["child", "children", "baby", "infant", "kid", "minor", "school",
             "lost child", "missing child", "daycare", "pediatric"]
        }
    }

    static func fromResourceType(_ type: String) -> EmergencyAgent? {
        allCases.first { $0.resourceType == type }
    }
}

enum EmergencyAgentClassifier {
    static func classify(_ text: String, preferred: EmergencyAgent? = nil) -> EmergencyAgent {
        if let preferred { return preferred }
        let lower = text.lowercased()
        if lower.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .ambulance
        }

        var best: EmergencyAgent = .ambulance
        var bestScore = 0
        for agent in EmergencyAgent.allCases {
            let score = agent.keywords.reduce(0) { $0 + (lower.contains($1) ? 1 : 0) }
            if score > bestScore {
                bestScore = score
                best = agent
            }
        }
        if bestScore == 0 && (lower.contains("sos") || lower.contains("emergency") || lower.contains("help")) {
            return .ambulance
        }
        return best
    }
}

struct CountryEmergencyInfo: Equatable {
    var countryCode: String
    var countryName: String
    var universalNumber: String
    var agentNumbers: [EmergencyAgent: String]

    func number(for agent: EmergencyAgent) -> String {
        agentNumbers[agent] ?? universalNumber
    }
}

enum CountryDispatchPolicy {
    private static let policies: [String: CountryEmergencyInfo] = [
        "IN": CountryEmergencyInfo(
            countryCode: "IN", countryName: "India", universalNumber: "112",
            agentNumbers: [
                .ambulance: "102", .police: "100", .fire: "101",
                .naturalDisaster: "112", .childCare: "1098"
            ]
        ),
        "US": CountryEmergencyInfo(
            countryCode: "US", countryName: "United States", universalNumber: "911",
            agentNumbers: Dictionary(uniqueKeysWithValues: EmergencyAgent.allCases.map { ($0, "911") })
        ),
        "GB": CountryEmergencyInfo(
            countryCode: "GB", countryName: "United Kingdom", universalNumber: "999",
            agentNumbers: Dictionary(uniqueKeysWithValues: EmergencyAgent.allCases.map { ($0, "999") })
        ),
        "AU": CountryEmergencyInfo(
            countryCode: "AU", countryName: "Australia", universalNumber: "000",
            agentNumbers: Dictionary(uniqueKeysWithValues: EmergencyAgent.allCases.map { ($0, "000") })
        ),
        "CA": CountryEmergencyInfo(
            countryCode: "CA", countryName: "Canada", universalNumber: "911",
            agentNumbers: Dictionary(uniqueKeysWithValues: EmergencyAgent.allCases.map { ($0, "911") })
        )
    ]

    private static let defaultPolicy = CountryEmergencyInfo(
        countryCode: "INT",
        countryName: "International",
        universalNumber: "112",
        agentNumbers: Dictionary(uniqueKeysWithValues: EmergencyAgent.allCases.map { ($0, "112") })
    )

    static func forLocation(_ geo: GeoLocation?) -> CountryEmergencyInfo {
        guard let code = geo?.countryCode?.uppercased() else { return defaultPolicy }
        return policies[code] ?? defaultPolicy
    }
}

struct SosDispatchResult: Equatable, Identifiable {
    var id = UUID()
    var agent: EmergencyAgent
    var incidentNumber: Int
    var locationLabel: String
    var countryName: String
    var emergencyNumber: String
    var universalNumber: String
    var dispatchedResource: String?
    var message: String
    var timestamp: Date = .now
}

struct SosProcessResult: Equatable {
    var sosResult: SosDispatchResult
    var agentResponse: AgentResponse
}
