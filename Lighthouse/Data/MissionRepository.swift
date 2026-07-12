import Foundation
import SwiftData

@MainActor
final class MissionRepository {
    private let context: ModelContext
    private let orchestrator: AgentOrchestrator
    private let locationService: LocationService

    init(context: ModelContext, locationService: LocationService) {
        self.context = context
        self.locationService = locationService
        self.orchestrator = AgentOrchestrator(context: context)
    }

    func activeMission() throws -> Mission? {
        let descriptor = FetchDescriptor<Mission>(
            predicate: #Predicate { $0.status == "active" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    func createMission(
        name: String,
        disasterType: String,
        location: String,
        missionGeo: GeoLocation? = nil
    ) throws -> Mission {
        let resolved = LocationResolver.resolve(reportedLocation: location, geo: missionGeo)
        let mission = Mission(
            name: name,
            disasterType: disasterType,
            location: resolved.displayName,
            latitude: resolved.latitude,
            longitude: resolved.longitude
        )
        context.insert(mission)
        addTimeline(
            missionId: mission.id,
            type: "mission_created",
            title: "Mission created",
            description: "\(name) — \(disasterType) in \(resolved.displayName)"
        )

        for name in ["Ambulance 1", "Ambulance 2"] {
            context.insert(ResourceUnit(missionId: mission.id, type: "ambulance", name: name))
        }
        for name in ["Medical Team Alpha", "Medical Team Bravo"] {
            context.insert(ResourceUnit(missionId: mission.id, type: "medical", name: name))
        }
        seedEmergencyAgentResources(missionId: mission.id)

        for pair in [("Volunteer A", "field"), ("Volunteer B", "field"), ("Volunteer C", "coordinator")] {
            context.insert(Volunteer(missionId: mission.id, name: pair.0, role: pair.1))
        }

        context.insert(
            ChatMessage(
                missionId: mission.id,
                role: "agent",
                content: "Mission active. I'm Lighthouse — your offline agent. Hold the mic and speak your field report."
            )
        )
        try context.save()
        return mission
    }

    func processMessage(missionId: String, userMessage: String) async throws -> AgentResponse {
        let reporterLocation = locationService.location ?? await locationService.refreshOnce()
        saveChat(missionId: missionId, role: "user", content: userMessage)
        let response = try orchestrator.processMessage(
            missionId: missionId,
            userMessage: userMessage,
            reporterLocation: reporterLocation
        )
        saveChat(missionId: missionId, role: "agent", content: response.message)
        try context.save()
        return response
    }

    func processSosDispatch(
        missionId: String,
        preferredAgent: EmergencyAgent?,
        description: String
    ) async throws -> SosProcessResult {
        ensureEmergencyResources(missionId: missionId)
        let reporterLocation = locationService.location ?? await locationService.refreshOnce()
        var userMessage = "SOS"
        if let preferredAgent {
            userMessage += " [\(preferredAgent.displayName)]"
        }
        if !description.isEmpty {
            userMessage += ": \(description)"
        }
        saveChat(missionId: missionId, role: "user", content: userMessage)
        let result = try orchestrator.processSosDispatch(
            missionId: missionId,
            preferredAgent: preferredAgent,
            description: description,
            reporterLocation: reporterLocation
        )
        saveChat(missionId: missionId, role: "agent", content: result.agentResponse.message)
        try context.save()
        return result
    }

    func ingestFieldCapture(missionId: String, photoPath: String, ocrText: String?) async throws -> AgentResponse {
        var message = "Field photo captured."
        if let ocrText, !ocrText.isEmpty {
            message += " Document OCR: \(ocrText.prefix(500))"
        } else {
            message += " No text detected — visual record saved."
        }
        let response = try await processMessage(missionId: missionId, userMessage: message)
        if let latest = try fetchIncidents(missionId).max(by: { $0.number < $1.number }) {
            latest.photoPath = photoPath
            latest.ocrText = ocrText ?? latest.ocrText
            latest.updatedAt = .now
            addTimeline(
                missionId: missionId,
                type: "field_capture",
                title: "Field capture — Incident #\(latest.number)",
                description: String((ocrText ?? "Photo attached").prefix(120)),
                incidentId: latest.id
            )
            try context.save()
        }
        return response
    }

    func ensureEmergencyResources(missionId: String) {
        seedEmergencyAgentResources(missionId: missionId)
        try? context.save()
    }

    func fetchIncidents(_ missionId: String) throws -> [Incident] {
        let descriptor = FetchDescriptor<Incident>(
            predicate: #Predicate { $0.missionId == missionId },
            sortBy: [SortDescriptor(\.number, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchMessages(_ missionId: String) throws -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.missionId == missionId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func fetchTimeline(_ missionId: String) throws -> [TimelineEvent] {
        let descriptor = FetchDescriptor<TimelineEvent>(
            predicate: #Predicate { $0.missionId == missionId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchResources(_ missionId: String) throws -> [ResourceUnit] {
        let descriptor = FetchDescriptor<ResourceUnit>(
            predicate: #Predicate { $0.missionId == missionId }
        )
        return try context.fetch(descriptor)
    }

    func fetchVolunteers(_ missionId: String) throws -> [Volunteer] {
        let descriptor = FetchDescriptor<Volunteer>(
            predicate: #Predicate { $0.missionId == missionId }
        )
        return try context.fetch(descriptor)
    }

    func fetchVictims(_ missionId: String) throws -> [Victim] {
        let descriptor = FetchDescriptor<Victim>(
            predicate: #Predicate { $0.missionId == missionId }
        )
        return try context.fetch(descriptor)
    }

    func fetchMemories(_ missionId: String) throws -> [MemoryEntry] {
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.missionId == missionId }
        )
        return try context.fetch(descriptor)
    }

    func stats(for missionId: String) throws -> MissionStats {
        let incidents = try fetchIncidents(missionId)
        let resources = try fetchResources(missionId)
        let volunteers = try fetchVolunteers(missionId)
        return MissionStats(
            incidents: incidents.count,
            volunteers: volunteers.count,
            resources: resources.count,
            criticalIncidents: incidents.filter { $0.priority == "critical" }.count,
            rescued: incidents.filter { $0.status == "rescued" }.count,
            awaitingRescue: incidents.filter { $0.status == "awaiting_rescue" }.count
        )
    }

    func resetAll() throws {
        try deleteAll(Mission.self)
        try deleteAll(Incident.self)
        try deleteAll(Victim.self)
        try deleteAll(Volunteer.self)
        try deleteAll(ResourceUnit.self)
        try deleteAll(TimelineEvent.self)
        try deleteAll(MemoryEntry.self)
        try deleteAll(ChatMessage.self)
        try context.save()

        let captures = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("captures", isDirectory: true)
        try? FileManager.default.removeItem(at: captures)
    }

    func exportJSON(missionId: String) throws -> String {
        guard let mission = try context.fetch(
            FetchDescriptor<Mission>(predicate: #Predicate { $0.id == missionId })
        ).first else {
            throw MissionSyncManager.SyncError.missionNotFound
        }
        let snapshot = MissionSnapshot(
            exportedAt: Date().timeIntervalSince1970 * 1000,
            mission: MissionDTO(
                id: mission.id, name: mission.name, status: mission.status,
                disasterType: mission.disasterType, location: mission.location,
                priority: mission.priority, latitude: mission.latitude, longitude: mission.longitude,
                createdAt: mission.createdAt.timeIntervalSince1970 * 1000,
                updatedAt: mission.updatedAt.timeIntervalSince1970 * 1000
            ),
            incidents: try fetchIncidents(missionId).map {
                IncidentDTO(
                    id: $0.id, missionId: $0.missionId, location: $0.location,
                    description: $0.incidentDescription, status: $0.status, priority: $0.priority,
                    reporter: $0.reporter, accessibility: $0.accessibility,
                    locationSource: $0.locationSource, number: $0.number, victimCount: $0.victimCount,
                    score: $0.score, confidence: $0.confidence, hasChildren: $0.hasChildren,
                    hasElderly: $0.hasElderly, hasUnconscious: $0.hasUnconscious,
                    latitude: $0.latitude, longitude: $0.longitude, photoPath: $0.photoPath,
                    ocrText: $0.ocrText,
                    createdAt: $0.createdAt.timeIntervalSince1970 * 1000,
                    updatedAt: $0.updatedAt.timeIntervalSince1970 * 1000
                )
            },
            victims: try fetchVictims(missionId).map {
                VictimDTO(
                    id: $0.id, incidentId: $0.incidentId, missionId: $0.missionId, label: $0.label,
                    ageGroup: $0.ageGroup, status: $0.status, conscious: $0.conscious,
                    trapped: $0.trapped, injured: $0.injured, rescuedBy: $0.rescuedBy,
                    createdAt: $0.createdAt.timeIntervalSince1970 * 1000
                )
            },
            volunteers: try fetchVolunteers(missionId).map {
                VolunteerDTO(
                    id: $0.id, missionId: $0.missionId, name: $0.name, role: $0.role,
                    status: $0.status, createdAt: $0.createdAt.timeIntervalSince1970 * 1000
                )
            },
            resources: try fetchResources(missionId).map {
                ResourceDTO(
                    id: $0.id, missionId: $0.missionId, type: $0.type, name: $0.name,
                    status: $0.status, assignedTo: $0.assignedTo,
                    createdAt: $0.createdAt.timeIntervalSince1970 * 1000
                )
            },
            timeline: try fetchTimeline(missionId).map {
                TimelineDTO(
                    id: $0.id, missionId: $0.missionId, eventType: $0.eventType, title: $0.title,
                    description: $0.eventDescription, incidentId: $0.incidentId,
                    createdAt: $0.createdAt.timeIntervalSince1970 * 1000
                )
            },
            messages: try fetchMessages(missionId).map {
                MessageDTO(
                    id: $0.id, missionId: $0.missionId, role: $0.role, content: $0.content,
                    metadata: $0.metadata, createdAt: $0.createdAt.timeIntervalSince1970 * 1000
                )
            },
            memories: try fetchMemories(missionId).map {
                MemoryDTO(
                    id: $0.id, missionId: $0.missionId, key: $0.key, value: $0.value,
                    source: $0.source, createdAt: $0.createdAt.timeIntervalSince1970 * 1000
                )
            }
        )
        return try MissionSyncManager.encode(snapshot)
    }

    func importJSON(_ json: String) throws -> Mission {
        let snapshot = try MissionSyncManager.decode(json)
        try resetAll()
        let m = snapshot.mission
        let mission = Mission(
            id: m.id, name: m.name, status: "active", disasterType: m.disasterType,
            location: m.location, latitude: m.latitude, longitude: m.longitude, priority: m.priority,
            createdAt: Date(timeIntervalSince1970: m.createdAt / 1000),
            updatedAt: Date(timeIntervalSince1970: m.updatedAt / 1000)
        )
        context.insert(mission)
        for i in snapshot.incidents {
            context.insert(
                Incident(
                    id: i.id, missionId: i.missionId, number: i.number, location: i.location,
                    incidentDescription: i.description, victimCount: i.victimCount, status: i.status,
                    priority: i.priority, score: i.score, reporter: i.reporter, confidence: i.confidence,
                    hasChildren: i.hasChildren, hasElderly: i.hasElderly, hasUnconscious: i.hasUnconscious,
                    accessibility: i.accessibility, latitude: i.latitude, longitude: i.longitude,
                    locationSource: i.locationSource, photoPath: i.photoPath, ocrText: i.ocrText,
                    createdAt: Date(timeIntervalSince1970: i.createdAt / 1000),
                    updatedAt: Date(timeIntervalSince1970: i.updatedAt / 1000)
                )
            )
        }
        for v in snapshot.victims {
            context.insert(
                Victim(
                    id: v.id, incidentId: v.incidentId, missionId: v.missionId, label: v.label,
                    ageGroup: v.ageGroup, conscious: v.conscious, trapped: v.trapped, injured: v.injured,
                    status: v.status, rescuedBy: v.rescuedBy,
                    createdAt: Date(timeIntervalSince1970: v.createdAt / 1000)
                )
            )
        }
        for v in snapshot.volunteers {
            context.insert(
                Volunteer(
                    id: v.id, missionId: v.missionId, name: v.name, role: v.role, status: v.status,
                    createdAt: Date(timeIntervalSince1970: v.createdAt / 1000)
                )
            )
        }
        for r in snapshot.resources {
            context.insert(
                ResourceUnit(
                    id: r.id, missionId: r.missionId, type: r.type, name: r.name, status: r.status,
                    assignedTo: r.assignedTo, createdAt: Date(timeIntervalSince1970: r.createdAt / 1000)
                )
            )
        }
        for t in snapshot.timeline {
            context.insert(
                TimelineEvent(
                    id: t.id, missionId: t.missionId, eventType: t.eventType, title: t.title,
                    eventDescription: t.description, incidentId: t.incidentId,
                    createdAt: Date(timeIntervalSince1970: t.createdAt / 1000)
                )
            )
        }
        for msg in snapshot.messages {
            context.insert(
                ChatMessage(
                    id: msg.id, missionId: msg.missionId, role: msg.role, content: msg.content,
                    metadata: msg.metadata, createdAt: Date(timeIntervalSince1970: msg.createdAt / 1000)
                )
            )
        }
        for mem in snapshot.memories {
            context.insert(
                MemoryEntry(
                    id: mem.id, missionId: mem.missionId, key: mem.key, value: mem.value,
                    source: mem.source, createdAt: Date(timeIntervalSince1970: mem.createdAt / 1000)
                )
            )
        }
        try context.save()
        return mission
    }

    private func seedEmergencyAgentResources(missionId: String) {
        let existing = Set((try? fetchResources(missionId).map(\.type)) ?? [])
        func seed(type: String, names: [String]) {
            guard !existing.contains(type) else { return }
            for name in names {
                context.insert(ResourceUnit(missionId: missionId, type: type, name: name))
            }
        }
        seed(type: "police", names: ["Police Unit 1", "Police Unit 2"])
        seed(type: "fire", names: ["Fire Unit 1", "Fire Rescue 2"])
        seed(type: "disaster", names: ["Disaster Response Team"])
        seed(type: "childcare", names: ["Child Protection Team"])
    }

    private func saveChat(missionId: String, role: String, content: String) {
        context.insert(ChatMessage(missionId: missionId, role: role, content: content))
    }

    private func addTimeline(
        missionId: String,
        type: String,
        title: String,
        description: String,
        incidentId: String? = nil
    ) {
        context.insert(
            TimelineEvent(
                missionId: missionId,
                eventType: type,
                title: title,
                eventDescription: description,
                incidentId: incidentId
            )
        )
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        try context.delete(model: type)
    }
}
