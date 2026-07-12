import Foundation
import SwiftData

@Model
final class Victim {
    @Attribute(.unique) var id: String
    var incidentId: String
    var missionId: String
    var label: String
    var ageGroup: String
    var conscious: Bool?
    var trapped: Bool?
    var injured: Bool?
    var status: String
    var rescuedBy: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        incidentId: String,
        missionId: String,
        label: String,
        ageGroup: String = "adult",
        conscious: Bool? = nil,
        trapped: Bool? = nil,
        injured: Bool? = nil,
        status: String = "awaiting_rescue",
        rescuedBy: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.incidentId = incidentId
        self.missionId = missionId
        self.label = label
        self.ageGroup = ageGroup
        self.conscious = conscious
        self.trapped = trapped
        self.injured = injured
        self.status = status
        self.rescuedBy = rescuedBy
        self.createdAt = createdAt
    }
}

@Model
final class Volunteer {
    @Attribute(.unique) var id: String
    var missionId: String
    var name: String
    var role: String
    var status: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        missionId: String,
        name: String,
        role: String = "field",
        status: String = "active",
        createdAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.name = name
        self.role = role
        self.status = status
        self.createdAt = createdAt
    }
}

@Model
final class ResourceUnit {
    @Attribute(.unique) var id: String
    var missionId: String
    var type: String
    var name: String
    var status: String
    var assignedTo: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        missionId: String,
        type: String,
        name: String,
        status: String = "available",
        assignedTo: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.type = type
        self.name = name
        self.status = status
        self.assignedTo = assignedTo
        self.createdAt = createdAt
    }
}

@Model
final class TimelineEvent {
    @Attribute(.unique) var id: String
    var missionId: String
    var eventType: String
    var title: String
    var eventDescription: String
    var incidentId: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        missionId: String,
        eventType: String,
        title: String,
        eventDescription: String,
        incidentId: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.eventType = eventType
        self.title = title
        self.eventDescription = eventDescription
        self.incidentId = incidentId
        self.createdAt = createdAt
    }
}

@Model
final class MemoryEntry {
    @Attribute(.unique) var id: String
    var missionId: String
    var key: String
    var value: String
    var source: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        missionId: String,
        key: String,
        value: String,
        source: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.key = key
        self.value = value
        self.source = source
        self.createdAt = createdAt
    }
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String
    var missionId: String
    var role: String
    var content: String
    var metadata: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        missionId: String,
        role: String,
        content: String,
        metadata: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.role = role
        self.content = content
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

struct MissionStats: Equatable {
    var incidents: Int = 0
    var volunteers: Int = 0
    var resources: Int = 0
    var criticalIncidents: Int = 0
    var rescued: Int = 0
    var awaitingRescue: Int = 0
}
