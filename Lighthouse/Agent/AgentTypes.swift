import Foundation

enum ReportIntent: String, Codable {
    case reportIncident = "REPORT_INCIDENT"
    case updateIncident = "UPDATE_INCIDENT"
    case reportRescue = "REPORT_RESCUE"
    case reportBlockedRoad = "REPORT_BLOCKED_ROAD"
    case query = "QUERY"
    case uncertainReport = "UNCERTAIN_REPORT"
    case medicalQuestion = "MEDICAL_QUESTION"
    case structuralQuestion = "STRUCTURAL_QUESTION"
    case general = "GENERAL"
}

struct ParsedReport: Equatable {
    var intent: ReportIntent = .general
    var location: String?
    var victimCount: Int?
    var description: String?
    var hasChildren = false
    var hasElderly = false
    var hasUnconscious = false
    var injured = false
    var trapped = false
    var uncertain = false
    var reporter = "Volunteer"
    var query: String?
    var incidentReference: Int?
}

struct Contradiction: Equatable {
    var field: String
    var previous: String
    var latest: String
    var incidentId: String
    var incidentNumber: Int
}

enum AgentLoopPhase: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case sense = "Sense"
    case decide = "Decide"
    case act = "Act"
    case verify = "Verify"
    case recover = "Recover"

    var id: String { rawValue }
}

struct MissionPlanStep: Equatable, Identifiable {
    var id = UUID()
    var action: String
    var resource: String?
    var incidentNumber: Int?

    init(action: String, resource: String? = nil, incidentNumber: Int? = nil) {
        self.action = action
        self.resource = resource
        self.incidentNumber = incidentNumber
    }
}

struct AgentResponse: Equatable {
    var message: String
    var needsClarification = false
    var clarificationFields: [String] = []
    var phase: AgentLoopPhase = .verify
    var phasesTraversed: [AgentLoopPhase] = []
    var planSteps: [MissionPlanStep] = []
    var usedGemma = false
}

struct AgentSessionState: Codable, Equatable {
    var pendingClarification = false
    var clarificationFields: [String] = []
    var targetIncidentId: String?
    var planSteps: [String] = []
    var lastPhase = "IDLE"
    var recoveryAttempts = 0

    static func fromJSON(_ value: String?) -> AgentSessionState {
        guard let value, let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(AgentSessionState.self, from: data)
        else { return AgentSessionState() }
        return decoded
    }

    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8)
        else { return "{}" }
        return string
    }
}
