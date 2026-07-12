import Foundation

struct LighthouseAgent {
    func process(
        parsed: ParsedReport,
        rawMessage: String,
        incidents: [Incident],
        victims: [Victim],
        resources: [ResourceUnit],
        timeline: [TimelineEvent],
        stats: MissionStats,
        reporterLocation: GeoLocation?
    ) -> AgentResponse {
        switch parsed.intent {
        case .structuralQuestion:
            return AgentResponse(message: VerificationEngine.structuralHandoff)
        case .medicalQuestion:
            return AgentResponse(message: VerificationEngine.medicalHandoff)
        case .uncertainReport:
            let fields = VerificationEngine.clarificationFields(uncertain: true)
            return AgentResponse(
                message: "I don't have enough information to update the rescue plan.\n\nPlease confirm:\n" +
                    fields.map { "• \($0)" }.joined(separator: "\n"),
                needsClarification: true,
                clarificationFields: fields
            )
        case .query:
            return handleQuery(
                parsed.query ?? rawMessage,
                incidents: incidents,
                victims: victims,
                resources: resources,
                timeline: timeline,
                stats: stats,
                reporterLocation: reporterLocation
            )
        case .general:
            return AgentResponse(
                message: "I'm monitoring the mission. Report incidents, rescue updates, or blocked roads. " +
                    "You can also ask about critical incidents, timeline, or resource status."
            )
        default:
            return AgentResponse(message: "Processing your report...")
        }
    }

    func formatNewIncident(_ incident: Incident, nextAction: String) -> String {
        var lines = [
            "Incident #\(incident.number) created",
            "",
            "Location: \(incident.location)"
        ]
        if let lat = incident.latitude, let lon = incident.longitude {
            lines.append(String(format: "GPS: %.4f, %.4f", lat, lon))
        }
        lines += [
            "Victims: \(incident.victimCount)",
            "Priority: \(incident.priority.uppercased()) (Score: \(incident.score))",
            "Status: Awaiting rescue",
            "Confidence: \(Int(incident.confidence * 100))%",
            "",
            nextAction
        ]
        return lines.joined(separator: "\n")
    }

    func formatContradiction(
        _ incident: Incident,
        contradiction: Contradiction,
        priority: String,
        score: Int
    ) -> String {
        """
        Conflicting reports detected on Incident #\(incident.number)

        Previous report: \(contradiction.previous) \(contradiction.field)
        Latest report: \(contradiction.latest) \(contradiction.field)

        Mission updated. Priority recalculated to \(priority.uppercased()) (Score: \(score)).
        """
    }

    func formatUpdate(
        _ incident: Incident,
        hasUnconscious: Bool,
        priority: String,
        score: Int,
        victimCount: Int
    ) -> String {
        var lines = ["Incident #\(incident.number) updated", ""]
        if hasUnconscious {
            lines.append("Unconscious victim reported — priority elevated.")
        }
        lines.append("Priority: \(priority.uppercased()) (Score: \(score))")
        lines.append("Victims: \(victimCount)")
        return lines.joined(separator: "\n")
    }

    func formatRescue(location: String, reporter: String, remaining: Int, nextAction: String) -> String {
        var lines = [
            "Rescue recorded at \(location)",
            "",
            "1 victim rescued by \(reporter)."
        ]
        if remaining > 0 {
            lines.append("\(remaining) victim(s) still awaiting rescue.")
        } else {
            lines.append("All victims rescued from this incident.")
        }
        lines += ["", nextAction]
        return lines.joined(separator: "\n")
    }

    func formatBlockedRoad(location: String, nextAction: String) -> String {
        "Road blocked — \(location)\n\nAccess restricted. Reprioritizing incidents in affected area.\n\n\(nextAction)"
    }

    func suggestNextAction(incidents: [Incident]) -> String {
        let pending = incidents
            .filter { $0.status == "awaiting_rescue" }
            .sorted { $0.score > $1.score }
        guard let top = pending.first else {
            return "No pending rescues. Continue monitoring for new reports."
        }
        return "Next action: Respond to Incident #\(top.number) at \(top.location) (Priority: \(top.priority), Score: \(top.score))"
    }

    private func handleQuery(
        _ query: String,
        incidents: [Incident],
        victims: [Victim],
        resources: [ResourceUnit],
        timeline: [TimelineEvent],
        stats: MissionStats,
        reporterLocation: GeoLocation?
    ) -> AgentResponse {
        let lower = query.lowercased()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        if lower.contains("where am i") || lower.contains("my location") || lower.contains("current location") {
            guard let reporterLocation else {
                return AgentResponse(
                    message: "GPS location unavailable. Enable location permission so I can pin incident coordinates."
                )
            }
            let accuracy = reporterLocation.accuracyMeters.map { " (±\(Int($0))m)" } ?? ""
            return AgentResponse(
                message: "Your current position:\n\(reporterLocation.shortLabel())\(accuracy)\n" +
                    "Coordinates: \(reporterLocation.formatCoordinates())"
            )
        }

        if lower.contains("nearest") && lower.contains("incident") {
            guard let reporterLocation else {
                return AgentResponse(message: "GPS unavailable — cannot calculate nearest incident.")
            }
            let nearest = incidents
                .compactMap { incident -> (Incident, Double)? in
                    guard let lat = incident.latitude, let lon = incident.longitude else { return nil }
                    return (incident, LocationResolver.distanceKm(from: reporterLocation, toLat: lat, toLon: lon))
                }
                .min { $0.1 < $1.1 }
            guard let nearest else {
                return AgentResponse(message: "No geotagged incidents yet. Report one with location enabled.")
            }
            return AgentResponse(
                message: String(
                    format: "Nearest incident: #\(nearest.0.number) at \(nearest.0.location)\nDistance: %.1f km · Priority: \(nearest.0.priority)",
                    nearest.1
                )
            )
        }

        if lower.contains("critical") {
            let critical = incidents.filter { $0.priority == "critical" }
            let high = incidents.filter { $0.priority == "high" }
            let all = critical + high
            if all.isEmpty {
                return AgentResponse(
                    message: "There are 0 critical incidents currently. \(stats.awaitingRescue) incident(s) awaiting rescue overall."
                )
            }
            let list = all.map {
                "• Incident #\($0.number) — \($0.location) (\($0.priority), score \($0.score), \($0.victimCount) victims)"
            }.joined(separator: "\n")
            return AgentResponse(message: "\(critical.count) critical and \(high.count) high-priority incidents:\n\n\(list)")
        }

        if lower.contains("children") {
            let childIncidents = incidents.filter(\.hasChildren)
            if childIncidents.isEmpty {
                return AgentResponse(message: "No incidents involving children reported yet.")
            }
            let list = childIncidents.map {
                "• Incident #\($0.number) — \($0.location) (\($0.victimCount) victims)"
            }.joined(separator: "\n")
            return AgentResponse(message: "Incidents involving children:\n\n\(list)")
        }

        if lower.contains("timeline") || lower.contains("history") {
            let list = timeline.map { "\(formatter.string(from: $0.createdAt)) — \($0.title)" }
                .joined(separator: "\n")
            return AgentResponse(message: "Mission Timeline:\n\n\(list)")
        }

        if lower.contains("ambulance") {
            let ambulances = resources.filter { $0.type == "ambulance" }
            let available = ambulances.filter { $0.status == "available" }.map(\.name).joined(separator: ", ")
            let assigned = ambulances.filter { $0.status == "assigned" }
                .map { "\($0.name) → \($0.assignedTo ?? "")" }
                .joined(separator: ", ")
            let awaiting = incidents.filter { $0.status == "awaiting_rescue" }.count
            return AgentResponse(
                message: "Ambulance status:\n• Available: \(available.isEmpty ? "None" : available)\n" +
                    "• Assigned: \(assigned.isEmpty ? "None" : assigned)\n• \(awaiting) incident(s) still need response"
            )
        }

        if lower.contains("volunteer") && lower.contains("rescued") {
            let rescued = victims.filter { $0.rescuedBy != nil }
            if rescued.isEmpty {
                return AgentResponse(message: "No rescues recorded yet.")
            }
            let list = rescued.map { "• \($0.label) rescued by \($0.rescuedBy ?? "")" }.joined(separator: "\n")
            return AgentResponse(message: "Rescue records:\n\n\(list)")
        }

        return AgentResponse(
            message: "Mission status: \(stats.incidents) incidents, \(stats.criticalIncidents) critical, " +
                "\(stats.rescued) rescued, \(stats.awaitingRescue) awaiting rescue."
        )
    }
}
