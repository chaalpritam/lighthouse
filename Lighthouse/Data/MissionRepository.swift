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
