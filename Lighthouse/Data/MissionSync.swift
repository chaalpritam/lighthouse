import Foundation

struct MissionSnapshot: Codable {
    var version: Int = 1
    var exportedAt: Double
    var mission: MissionDTO
    var incidents: [IncidentDTO]
    var victims: [VictimDTO]
    var volunteers: [VolunteerDTO]
    var resources: [ResourceDTO]
    var timeline: [TimelineDTO]
    var messages: [MessageDTO]
    var memories: [MemoryDTO]
}

struct MissionDTO: Codable {
    var id, name, status, disasterType, location, priority: String
    var latitude, longitude: Double?
    var createdAt, updatedAt: Double
}

struct IncidentDTO: Codable {
    var id, missionId, location, description, status, priority, reporter, accessibility, locationSource: String
    var number, victimCount, score: Int
    var confidence: Double
    var hasChildren, hasElderly, hasUnconscious: Bool
    var latitude, longitude: Double?
    var photoPath, ocrText: String?
    var createdAt, updatedAt: Double
}

struct VictimDTO: Codable {
    var id, incidentId, missionId, label, ageGroup, status: String
    var conscious, trapped, injured: Bool?
    var rescuedBy: String?
    var createdAt: Double
}

struct VolunteerDTO: Codable {
    var id, missionId, name, role, status: String
    var createdAt: Double
}

struct ResourceDTO: Codable {
    var id, missionId, type, name, status: String
    var assignedTo: String?
    var createdAt: Double
}

struct TimelineDTO: Codable {
    var id, missionId, eventType, title, description: String
    var incidentId: String?
    var createdAt: Double
}

struct MessageDTO: Codable {
    var id, missionId, role, content: String
    var metadata: String?
    var createdAt: Double
}

struct MemoryDTO: Codable {
    var id, missionId, key, value, source: String
    var createdAt: Double
}

enum MissionSyncManager {
    enum SyncError: LocalizedError {
        case missionNotFound, encodeFailed, decodeFailed
        var errorDescription: String? {
            switch self {
            case .missionNotFound: return "Mission not found"
            case .encodeFailed: return "Failed to encode snapshot"
            case .decodeFailed: return "Failed to decode snapshot"
            }
        }
    }

    static func encode(_ snapshot: MissionSnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        guard let string = String(data: data, encoding: .utf8) else { throw SyncError.encodeFailed }
        return string
    }

    static func decode(_ json: String) throws -> MissionSnapshot {
        guard let data = json.data(using: .utf8) else { throw SyncError.decodeFailed }
        return try JSONDecoder().decode(MissionSnapshot.self, from: data)
    }
}
