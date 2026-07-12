import Foundation
import SwiftData

@MainActor
final class AgentOrchestrator {
    private let context: ModelContext
    private let agent = LighthouseAgent()
    private let sessionKey = "agent_session"

    init(context: ModelContext) {
        self.context = context
    }

    func processMessage(
        missionId: String,
        userMessage: String,
        reporterLocation: GeoLocation?
    ) throws -> AgentResponse {
        var phases: [AgentLoopPhase] = [.sense]
        var session = loadSession(missionId: missionId)

        let parsed: ParsedReport
        if session.pendingClarification {
            parsed = handleClarificationAnswer(userMessage, session: session, missionId: missionId)
        } else {
            parsed = ReportParser.parse(userMessage)
        }

        phases.append(.decide)
        let incidents = fetchIncidents(missionId)
        let resources = fetchResources(missionId)

        if parsed.uncertain && parsed.intent != .uncertainReport {
            let fields = VerificationEngine.clarificationFields(uncertain: true)
            session.pendingClarification = true
            session.clarificationFields = fields
            session.targetIncidentId = incidents.last?.id
            session.lastPhase = AgentLoopPhase.decide.rawValue
            saveSession(missionId: missionId, session: session)
            phases.append(.recover)
            return AgentResponse(
                message: "I need clarification before updating the plan.\n\n" +
                    fields.map { "• \($0)" }.joined(separator: "\n"),
                needsClarification: true,
                clarificationFields: fields,
                phase: .recover,
                phasesTraversed: phases
            )
        }

        phases.append(.act)

        var response: AgentResponse
        switch parsed.intent {
        case .reportIncident:
            response = try handleNewIncident(missionId: missionId, parsed: parsed, resources: resources, reporterLocation: reporterLocation)
        case .updateIncident:
            response = try handleUpdateIncident(missionId: missionId, parsed: parsed, reporterLocation: reporterLocation)
        case .reportRescue:
            response = try handleRescue(missionId: missionId, parsed: parsed)
        case .reportBlockedRoad:
            response = try handleBlockedRoad(missionId: missionId, parsed: parsed, reporterLocation: reporterLocation)
        default:
            let victims = fetchVictims(missionId)
            let timeline = fetchTimeline(missionId)
            let stats = buildStats(incidents: incidents, resources: resources)
            response = agent.process(
                parsed: parsed,
                rawMessage: userMessage,
                incidents: incidents,
                victims: victims,
                resources: resources,
                timeline: timeline,
                stats: stats,
                reporterLocation: reporterLocation
            )
        }

        phases.append(.verify)

        let updatedIncidents = fetchIncidents(missionId)
        let updatedResources = fetchResources(missionId)
        let planSteps = MissionPlanner.buildPlan(incidents: updatedIncidents, resources: updatedResources)
        session.pendingClarification = response.needsClarification
        session.clarificationFields = response.clarificationFields
        session.planSteps = planSteps.map(\.action)
        session.lastPhase = AgentLoopPhase.verify.rawValue
        session.recoveryAttempts = response.needsClarification ? session.recoveryAttempts + 1 : 0
        saveSession(missionId: missionId, session: session)

        let planText = MissionPlanner.formatPlan(planSteps)
        var finalMessage = response.message
        if !planText.isEmpty && [.reportIncident, .updateIncident, .reportRescue, .reportBlockedRoad].contains(parsed.intent) {
            finalMessage += "\n\n\(planText)"
        }
        if response.needsClarification {
            phases.append(.recover)
        }

        response.message = finalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        response.phase = response.needsClarification ? .recover : .verify
        response.phasesTraversed = phases
        response.planSteps = planSteps
        return response
    }

    func processSosDispatch(
        missionId: String,
        preferredAgent: EmergencyAgent?,
        description: String,
        reporterLocation: GeoLocation?
    ) throws -> SosProcessResult {
        let agentType = EmergencyAgentClassifier.classify(description, preferred: preferredAgent)
        let country = CountryDispatchPolicy.forLocation(reporterLocation)
        let resolved = LocationResolver.resolve(reportedLocation: description.isEmpty ? nil : description, geo: reporterLocation)
        let resources = fetchResources(missionId)
        let lower = description.lowercased()
        let hasChildren = agentType == .childCare ||
            lower.contains("child") || lower.contains("baby") || lower.contains("kid")
        let score = PriorityCalculator.calculate(
            victimCount: 1,
            hasChildren: hasChildren,
            hasElderly: false,
            hasUnconscious: agentType == .ambulance,
            injured: agentType == .ambulance,
            trapped: agentType == .fire,
            accessibility: "unknown",
            ageMinutes: 0,
            rescueProgress: 0
        )

        let number = (fetchIncidents(missionId).map(\.number).max() ?? 0) + 1
        let incident = Incident(
            missionId: missionId,
            number: number,
            location: resolved.displayName,
            incidentDescription: description.isEmpty ? "SOS — \(agentType.displayName)" : description,
            victimCount: 1,
            priority: score.priority,
            score: score.score,
            reporter: "SOS Reporter",
            hasChildren: hasChildren,
            hasUnconscious: agentType == .ambulance,
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            locationSource: resolved.source
        )
        context.insert(incident)
        context.insert(
            Victim(
                incidentId: incident.id,
                missionId: missionId,
                label: "SOS victim",
                ageGroup: hasChildren ? "child" : "adult",
                trapped: agentType == .fire ? true : nil,
                injured: agentType == .ambulance ? true : nil
            )
        )

        let dispatched = resources.first { $0.type == agentType.resourceType && $0.status == "available" }
        if let unit = dispatched {
            unit.status = "assigned"
            unit.assignedTo = "SOS Incident #\(number) — \(agentType.displayName)"
            addTimeline(
                missionId: missionId,
                type: "sos_dispatched",
                title: "SOS → \(agentType.displayName)",
                description: "\(unit.name) dispatched for Incident #\(number) at \(resolved.displayName)",
                incidentId: incident.id
            )
        } else {
            addTimeline(
                missionId: missionId,
                type: "sos_dispatched",
                title: "SOS → \(agentType.displayName)",
                description: "No available \(agentType.displayName) unit — alert logged for Incident #\(number)",
                incidentId: incident.id
            )
        }

        addTimeline(
            missionId: missionId,
            type: "incident_reported",
            title: "SOS Incident #\(number)",
            description: "\(agentType.displayName): \(description.isEmpty ? "Emergency alert" : description)",
            incidentId: incident.id
        )

        let emergencyNumber = country.number(for: agentType)
        var message = """
        SOS sent to \(agentType.displayName).
        Location: \(resolved.displayName)
        Region: \(country.countryName) (\(country.countryCode))
        """
        if let dispatched {
            message += "\n\(dispatched.name) is being dispatched to you."
        } else {
            message += "\nNo \(agentType.displayName) unit available locally — incident logged."
        }
        message += "\n\nCall \(agentType.displayName): \(emergencyNumber)"
        if emergencyNumber != country.universalNumber {
            message += " · Universal: \(country.universalNumber)"
        }
        message += "\n\nStay on the line if you can. Help is being coordinated."

        let planSteps = MissionPlanner.buildPlan(
            incidents: fetchIncidents(missionId),
            resources: fetchResources(missionId)
        )
        let sos = SosDispatchResult(
            agent: agentType,
            incidentNumber: number,
            locationLabel: resolved.displayName,
            countryName: country.countryName,
            emergencyNumber: emergencyNumber,
            universalNumber: country.universalNumber,
            dispatchedResource: dispatched?.name,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try context.save()
        return SosProcessResult(
            sosResult: sos,
            agentResponse: AgentResponse(
                message: sos.message,
                phase: .verify,
                phasesTraversed: [.sense, .decide, .act, .verify],
                planSteps: planSteps
            )
        )
    }

    // MARK: - Handlers

    private func handleClarificationAnswer(
        _ userMessage: String,
        session: AgentSessionState,
        missionId: String
    ) -> ParsedReport {
        var base = ReportParser.parse(userMessage)
        let target = session.targetIncidentId.flatMap { id in
            fetchIncidents(missionId).first { $0.id == id }
        } ?? fetchIncidents(missionId).last
        base.intent = target != nil ? .updateIncident : base.intent
        base.uncertain = false
        base.location = base.location ?? target?.location
        base.victimCount = base.victimCount ?? target?.victimCount
        return base
    }

    private func handleNewIncident(
        missionId: String,
        parsed: ParsedReport,
        resources: [ResourceUnit],
        reporterLocation: GeoLocation?
    ) throws -> AgentResponse {
        let resolved = LocationResolver.resolve(reportedLocation: parsed.location, geo: reporterLocation)
        let score = PriorityCalculator.calculate(
            victimCount: parsed.victimCount ?? 1,
            hasChildren: parsed.hasChildren,
            hasElderly: parsed.hasElderly,
            hasUnconscious: parsed.hasUnconscious,
            injured: parsed.injured,
            trapped: parsed.trapped,
            accessibility: "unknown",
            ageMinutes: 0,
            rescueProgress: 0
        )
        let number = (fetchIncidents(missionId).map(\.number).max() ?? 0) + 1
        let incident = Incident(
            missionId: missionId,
            number: number,
            location: resolved.displayName,
            incidentDescription: parsed.description ?? "Field report",
            victimCount: parsed.victimCount ?? 1,
            priority: score.priority,
            score: score.score,
            reporter: parsed.reporter,
            hasChildren: parsed.hasChildren,
            hasElderly: parsed.hasElderly,
            hasUnconscious: parsed.hasUnconscious,
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            locationSource: resolved.source
        )
        context.insert(incident)

        for i in 0..<incident.victimCount {
            let ageGroup: String
            if parsed.hasChildren && i < 2 {
                ageGroup = "child"
            } else if parsed.hasElderly && i == incident.victimCount - 1 {
                ageGroup = "elderly"
            } else {
                ageGroup = "adult"
            }
            context.insert(
                Victim(
                    incidentId: incident.id,
                    missionId: missionId,
                    label: "Victim \(i + 1)",
                    ageGroup: ageGroup,
                    conscious: parsed.hasUnconscious && i == 0 ? false : nil,
                    trapped: parsed.trapped ? true : nil,
                    injured: (parsed.injured || parsed.hasUnconscious) ? true : nil
                )
            )
        }

        let (ambulance, medical) = MissionPlanner.assignResources(for: incident, resources: resources)
        var dispatchNote = ""
        if let amb = ambulance {
            amb.status = "assigned"
            amb.assignedTo = "Incident #\(number) — \(incident.location)"
            dispatchNote = "Dispatched \(amb.name) to Incident #\(number)."
            addTimeline(
                missionId: missionId,
                type: "resource_assigned",
                title: "\(amb.name) dispatched",
                description: "Assigned to Incident #\(number) at \(incident.location)",
                incidentId: incident.id
            )
        }
        if let med = medical {
            med.status = "assigned"
            med.assignedTo = "Incident #\(number) — medical support"
            dispatchNote += " \(med.name) on standby."
            addTimeline(
                missionId: missionId,
                type: "resource_assigned",
                title: "\(med.name) deployed",
                description: "Medical support for Incident #\(number)",
                incidentId: incident.id
            )
        }

        addTimeline(
            missionId: missionId,
            type: "incident_reported",
            title: "Incident #\(number) reported",
            description: "\(incident.location): \(incident.incidentDescription)",
            incidentId: incident.id
        )

        let lat = incident.latitude.map { String($0) } ?? "null"
        let lng = incident.longitude.map { String($0) } ?? "null"
        context.insert(
            MemoryEntry(
                missionId: missionId,
                key: "incident_\(number)",
                value: #"{"location":"\#(incident.location)","victims":\#(incident.victimCount),"lat":\#(lat),"lng":\#(lng)}"#,
                source: parsed.reporter
            )
        )

        try context.save()
        let nextAction = agent.suggestNextAction(incidents: fetchIncidents(missionId))
        var message = agent.formatNewIncident(incident, nextAction: nextAction)
        if !dispatchNote.trimmingCharacters(in: .whitespaces).isEmpty {
            message += "\n\n\(dispatchNote.trimmingCharacters(in: .whitespaces))"
        }
        return AgentResponse(message: message)
    }

    private func handleUpdateIncident(
        missionId: String,
        parsed: ParsedReport,
        reporterLocation: GeoLocation?
    ) throws -> AgentResponse {
        let incidents = fetchIncidents(missionId)
        let target: Incident?
        if let ref = parsed.incidentReference {
            target = incidents.first { $0.number == ref }
        } else if let location = parsed.location {
            target = incidents.first { $0.location.localizedCaseInsensitiveCompare(location) == .orderedSame }
                ?? incidents.last
        } else {
            target = incidents.last
        }

        guard let target else {
            return AgentResponse(
                message: "No matching incident found. Which location or incident number?",
                needsClarification: true,
                clarificationFields: ["incident location or number"]
            )
        }

        if let contradiction = VerificationEngine.detectContradiction(existing: target, newVictimCount: parsed.victimCount),
           let newCount = parsed.victimCount {
            let ageMinutes = Date().timeIntervalSince(target.createdAt) / 60
            let score = PriorityCalculator.calculate(
                victimCount: newCount,
                hasChildren: parsed.hasChildren || target.hasChildren,
                hasElderly: parsed.hasElderly || target.hasElderly,
                hasUnconscious: parsed.hasUnconscious || target.hasUnconscious,
                injured: true,
                trapped: true,
                accessibility: target.accessibility,
                ageMinutes: ageMinutes,
                rescueProgress: 0
            )
            target.victimCount = newCount
            target.hasChildren = parsed.hasChildren || target.hasChildren
            target.hasElderly = parsed.hasElderly || target.hasElderly
            target.hasUnconscious = parsed.hasUnconscious || target.hasUnconscious
            target.priority = score.priority
            target.score = score.score
            target.updatedAt = .now
            addTimeline(
                missionId: missionId,
                type: "contradiction_detected",
                title: "Contradiction on Incident #\(target.number)",
                description: "\(contradiction.field): \(contradiction.previous) → \(contradiction.latest)",
                incidentId: target.id
            )
            addTimeline(
                missionId: missionId,
                type: "priority_updated",
                title: "Priority updated — Incident #\(target.number)",
                description: "New priority: \(score.priority) (score \(score.score))",
                incidentId: target.id
            )
            try context.save()
            return AgentResponse(
                message: agent.formatContradiction(target, contradiction: contradiction, priority: score.priority, score: score.score)
            )
        }

        let victimCount = parsed.victimCount ?? target.victimCount
        let ageMinutes = Date().timeIntervalSince(target.createdAt) / 60
        let score = PriorityCalculator.calculate(
            victimCount: victimCount,
            hasChildren: parsed.hasChildren || target.hasChildren,
            hasElderly: parsed.hasElderly || target.hasElderly,
            hasUnconscious: parsed.hasUnconscious || target.hasUnconscious,
            injured: parsed.hasUnconscious || parsed.injured,
            trapped: parsed.trapped || true,
            accessibility: target.accessibility,
            ageMinutes: ageMinutes,
            rescueProgress: 0
        )
        target.victimCount = victimCount
        target.hasChildren = parsed.hasChildren || target.hasChildren
        target.hasElderly = parsed.hasElderly || target.hasElderly
        target.hasUnconscious = parsed.hasUnconscious || target.hasUnconscious
        target.priority = score.priority
        target.score = score.score
        target.latitude = reporterLocation?.latitude ?? target.latitude
        target.longitude = reporterLocation?.longitude ?? target.longitude
        if reporterLocation != nil { target.locationSource = "reported+gps" }
        target.updatedAt = .now

        for victim in fetchVictims(missionId).filter({ $0.incidentId == target.id && $0.status != "rescued" }) {
            if parsed.hasUnconscious { victim.conscious = false }
            if parsed.injured || parsed.hasUnconscious { victim.injured = true }
            if parsed.trapped { victim.trapped = true }
        }

        addTimeline(
            missionId: missionId,
            type: "priority_updated",
            title: "Incident #\(target.number) updated",
            description: "Priority: \(score.priority) (score \(score.score))",
            incidentId: target.id
        )
        try context.save()
        return AgentResponse(
            message: agent.formatUpdate(
                target,
                hasUnconscious: parsed.hasUnconscious,
                priority: score.priority,
                score: score.score,
                victimCount: victimCount
            )
        )
    }

    private func handleRescue(missionId: String, parsed: ParsedReport) throws -> AgentResponse {
        let incidents = fetchIncidents(missionId)
        let active = incidents.filter { $0.status != "rescued" }
        let target: Incident?
        if let ref = parsed.incidentReference {
            target = incidents.first { $0.number == ref }
        } else if let location = parsed.location {
            target = active.first { $0.location.localizedCaseInsensitiveContains(location) }
        } else {
            target = active.max { $0.score < $1.score }
        }
        guard let target else {
            return AgentResponse(message: "No active incidents found for rescue update.")
        }

        let victims = fetchVictims(missionId).filter { $0.incidentId == target.id && $0.status != "rescued" }
        if let first = victims.first {
            first.status = "rescued"
            first.rescuedBy = parsed.reporter
        }

        let remaining = max(target.victimCount - 1, 0)
        if remaining <= 0 || victims.count <= 1 {
            target.status = "rescued"
            target.score = 10
            target.priority = "low"
            target.updatedAt = .now
            for res in fetchResources(missionId) where res.assignedTo?.contains("Incident #\(target.number)") == true {
                res.status = "available"
                res.assignedTo = nil
            }
        } else {
            target.victimCount = remaining
            target.status = "in_progress"
            target.updatedAt = .now
        }

        addTimeline(
            missionId: missionId,
            type: "rescue_completed",
            title: "Rescue at \(target.location)",
            description: "One victim rescued by \(parsed.reporter)",
            incidentId: target.id
        )
        try context.save()
        let nextAction = agent.suggestNextAction(incidents: fetchIncidents(missionId))
        return AgentResponse(
            message: agent.formatRescue(
                location: target.location,
                reporter: parsed.reporter,
                remaining: remaining,
                nextAction: nextAction
            )
        )
    }

    private func handleBlockedRoad(
        missionId: String,
        parsed: ParsedReport,
        reporterLocation: GeoLocation?
    ) throws -> AgentResponse {
        let resolved = LocationResolver.resolve(reportedLocation: parsed.location, geo: reporterLocation)
        let location = resolved.displayName
        let lat = resolved.latitude.map { String($0) } ?? "null"
        let lng = resolved.longitude.map { String($0) } ?? "null"
        context.insert(
            MemoryEntry(
                missionId: missionId,
                key: "blocked_road_\(location)",
                value: #"{"location":"\#(location)","lat":\#(lat),"lng":\#(lng)}"#,
                source: parsed.reporter
            )
        )
        addTimeline(
            missionId: missionId,
            type: "road_blocked",
            title: "Road blocked",
            description: "\(location) — access restricted"
        )

        let keyword = (parsed.location ?? resolved.displayName)
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .first { $0.count > 3 } ?? location.lowercased()

        for inc in fetchIncidents(missionId) {
            let textMatch = inc.location.lowercased().contains(keyword)
            let nearReporter: Bool
            if let reporterLocation, let lat = inc.latitude, let lon = inc.longitude {
                nearReporter = LocationResolver.distanceKm(from: reporterLocation, toLat: lat, toLon: lon) < 2
            } else {
                nearReporter = false
            }
            if textMatch || nearReporter {
                inc.accessibility = "blocked"
                inc.updatedAt = .now
            }
        }

        try context.save()
        let nextAction = agent.suggestNextAction(incidents: fetchIncidents(missionId))
        return AgentResponse(message: agent.formatBlockedRoad(location: location, nextAction: nextAction))
    }

    // MARK: - Persistence helpers

    private func fetchIncidents(_ missionId: String) -> [Incident] {
        let descriptor = FetchDescriptor<Incident>(
            predicate: #Predicate { $0.missionId == missionId },
            sortBy: [SortDescriptor(\.number)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchResources(_ missionId: String) -> [ResourceUnit] {
        let descriptor = FetchDescriptor<ResourceUnit>(
            predicate: #Predicate { $0.missionId == missionId }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchVictims(_ missionId: String) -> [Victim] {
        let descriptor = FetchDescriptor<Victim>(
            predicate: #Predicate { $0.missionId == missionId }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchTimeline(_ missionId: String) -> [TimelineEvent] {
        let descriptor = FetchDescriptor<TimelineEvent>(
            predicate: #Predicate { $0.missionId == missionId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func loadSession(missionId: String) -> AgentSessionState {
        let key = sessionKey
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.missionId == missionId && $0.key == key }
        )
        let memory = try? context.fetch(descriptor).first
        return AgentSessionState.fromJSON(memory?.value)
    }

    private func saveSession(missionId: String, session: AgentSessionState) {
        let key = sessionKey
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.missionId == missionId && $0.key == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.value = session.toJSON()
        } else {
            context.insert(
                MemoryEntry(missionId: missionId, key: key, value: session.toJSON(), source: "agent")
            )
        }
        try? context.save()
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

    private func buildStats(incidents: [Incident], resources: [ResourceUnit]) -> MissionStats {
        MissionStats(
            incidents: incidents.count,
            volunteers: 3,
            resources: resources.count,
            criticalIncidents: incidents.filter { $0.priority == "critical" }.count,
            rescued: incidents.filter { $0.status == "rescued" }.count,
            awaitingRescue: incidents.filter { $0.status == "awaiting_rescue" }.count
        )
    }
}
