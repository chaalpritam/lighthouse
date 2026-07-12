import Foundation

enum MissionPlanner {
    static func buildPlan(incidents: [Incident], resources: [ResourceUnit]) -> [MissionPlanStep] {
        let pending = incidents
            .filter { $0.status == "awaiting_rescue" || $0.status == "in_progress" }
            .sorted { $0.score > $1.score }

        guard !pending.isEmpty else {
            return [MissionPlanStep(action: "Monitor field — no active rescues pending")]
        }

        var steps: [MissionPlanStep] = []
        let availableAmbulances = resources.filter { $0.type == "ambulance" && $0.status == "available" }
        let availableMedical = resources.filter { $0.type == "medical" && $0.status == "available" }

        for (index, incident) in pending.prefix(3).enumerated() {
            let ambulance = availableAmbulances.indices.contains(index) ? availableAmbulances[index] : nil
            let medical = (incident.hasUnconscious || incident.priority == "critical")
                ? availableMedical.first
                : nil

            steps.append(
                MissionPlanStep(
                    action: "Respond to Incident #\(incident.number) at \(incident.location)",
                    resource: ambulance?.name,
                    incidentNumber: incident.number
                )
            )
            if let medical {
                steps.append(
                    MissionPlanStep(
                        action: "Deploy \(medical.name) for medical support",
                        resource: medical.name,
                        incidentNumber: incident.number
                    )
                )
            }
            if incident.accessibility == "blocked" {
                steps.append(
                    MissionPlanStep(
                        action: "Find alternate route — access blocked near \(incident.location)",
                        incidentNumber: incident.number
                    )
                )
            }
        }
        return steps
    }

    static func assignResources(
        for incident: Incident,
        resources: [ResourceUnit]
    ) -> (ResourceUnit?, ResourceUnit?) {
        let ambulance = resources.first { $0.type == "ambulance" && $0.status == "available" }
        let medical = (incident.hasUnconscious || incident.priority == "critical")
            ? resources.first { $0.type == "medical" && $0.status == "available" }
            : nil
        return (ambulance, medical)
    }

    static func formatPlan(_ steps: [MissionPlanStep]) -> String {
        guard !steps.isEmpty else { return "" }
        var lines = ["Agent plan:"]
        for (index, step) in steps.enumerated() {
            let resource = step.resource.map { " via \($0)" } ?? ""
            lines.append("\(index + 1). \(step.action)\(resource)")
        }
        return lines.joined(separator: "\n")
    }
}
