import Foundation

enum ReportParser {
    private static let locationPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:at|near|in)\s+(building\s+[a-z0-9]+)"#,
            #"(building\s+[a-z0-9]+)"#,
            #"(bridge\s+[a-z0-9]*)"#,
            #"(road\s+[a-z0-9]+)"#,
            #"(sector\s+\d+)"#
        ]
        return patterns.compactMap {
            try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
        }
    }()

    static func parse(_ text: String) -> ParsedReport {
        let lower = text.lowercased()

        if lower.contains("how many") || lower.contains("show all") ||
            lower.contains("show incidents") || lower.contains("show blocked") ||
            lower.contains("which volunteer") || lower.contains("which incidents") ||
            lower.contains("timeline") || lower.contains("critical incidents") ||
            lower.contains("where am i") || lower.contains("my location") ||
            lower.contains("current location") || lower.contains("nearest incident") {
            return ParsedReport(intent: .query, query: text)
        }

        if lower.contains("structure") && (lower.contains("safe") || lower.contains("collapse")) {
            return ParsedReport(intent: .structuralQuestion)
        }

        if lower.contains("diagnose") || lower.contains("medical condition") {
            return ParsedReport(intent: .medicalQuestion)
        }

        if lower.contains("may be") || lower.contains("might be") ||
            lower.contains("possibly") || lower.contains("another victim") ||
            lower.contains("another child") {
            return ParsedReport(intent: .uncertainReport, description: text, uncertain: true)
        }

        if lower.contains("rescued") || lower.contains("evacuated") {
            return ParsedReport(
                intent: .reportRescue,
                incidentReference: extractIncidentRef(text)
            )
        }

        if lower.contains("road blocked") || lower.contains("blocked road") || lower.contains("road is blocked") {
            return ParsedReport(
                intent: .reportBlockedRoad,
                location: extractLocation(text) ?? "Unknown road",
                description: text
            )
        }

        let isUpdate = lower.contains("actually") || lower.contains("update") ||
            lower.contains("correction") || lower.contains("unconscious") ||
            lower.contains("there are now")

        if isUpdate {
            return ParsedReport(
                intent: .updateIncident,
                location: extractLocation(text),
                victimCount: extractVictimCount(text),
                description: text,
                hasChildren: lower.contains("child"),
                hasElderly: lower.contains("elderly") || lower.contains("old"),
                hasUnconscious: lower.contains("unconscious"),
                injured: lower.contains("injured"),
                trapped: lower.contains("trapped"),
                incidentReference: extractIncidentRef(text)
            )
        }

        if lower.contains("collapsed") || lower.contains("trapped") ||
            lower.contains("fire") || lower.contains("flood") || lower.contains("injured") ||
            lower.contains("emergency") || lower.contains("help me") || lower.contains("sos") ||
            lower.contains("accident") || lower.contains("explosion") || lower.contains("bleeding") ||
            lower.contains("can't breathe") || lower.contains("heart attack") || lower.contains("stroke") ||
            lower.contains("drowning") || lower.contains("earthquake") || lower.contains("tsunami") ||
            lower.contains("someone hurt") || lower.contains("people hurt") || lower.contains("need help") ||
            lower.contains("danger") || lower.contains("unsafe") || lower.contains("smoke") ||
            lower.contains("gas leak") || lower.contains("car crash") || lower.contains("stuck") ||
            lower.contains("attack") || lower.contains("medical emergency") || lower.contains("wildfire") {
            return ParsedReport(
                intent: .reportIncident,
                location: extractLocation(text),
                victimCount: extractVictimCount(text) ?? 1,
                description: text,
                hasChildren: lower.contains("child"),
                hasElderly: lower.contains("elderly"),
                hasUnconscious: lower.contains("unconscious"),
                injured: lower.contains("injured") || lower.contains("hurt") || lower.contains("bleeding"),
                trapped: lower.contains("trapped") || lower.contains("stuck")
            )
        }

        return ParsedReport(intent: .general, description: text)
    }

    private static func extractLocation(_ text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for pattern in locationPatterns {
            if let match = pattern.firstMatch(in: text, range: range),
               match.numberOfRanges > 1,
               let swiftRange = Range(match.range(at: 1), in: text) {
                return String(text[swiftRange]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func extractVictimCount(_ text: String) -> Int? {
        if let regex = try? NSRegularExpression(
            pattern: #"(\d+)\s+(?:people|persons|victims|adults|trapped)"#,
            options: .caseInsensitive
        ),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Int(text[range])
        }
        let lower = text.lowercased()
        if lower.contains("three") { return 3 }
        if lower.contains("two") { return 2 }
        if lower.contains("one") { return 1 }
        return nil
    }

    private static func extractIncidentRef(_ text: String) -> Int? {
        guard let regex = try? NSRegularExpression(
            pattern: #"incident\s*#?(\d+)"#,
            options: .caseInsensitive
        ),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[range])
    }
}

enum PriorityCalculator {
    struct ScoreResult: Equatable {
        var score: Int
        var priority: String
    }

    static func calculate(
        victimCount: Int,
        hasChildren: Bool,
        hasElderly: Bool,
        hasUnconscious: Bool,
        injured: Bool,
        trapped: Bool,
        accessibility: String,
        ageMinutes: Double,
        rescueProgress: Double
    ) -> ScoreResult {
        var score = 30
        score += min(victimCount * 8, 24)
        if hasChildren { score += 25 }
        if hasElderly { score += 15 }
        if hasUnconscious { score += 20 }
        if injured { score += 12 }
        if trapped { score += 10 }
        if accessibility == "blocked" || accessibility == "difficult" { score += 5 }
        score += min(Int(ageMinutes * 0.5), 15)
        score -= Int(rescueProgress * 10)
        score = min(max(score, 0), 100)

        let priority: String
        switch score {
        case 85...: priority = "critical"
        case 65..<85: priority = "high"
        case 40..<65: priority = "medium"
        default: priority = "low"
        }
        return ScoreResult(score: score, priority: priority)
    }
}

enum VerificationEngine {
    static let structuralHandoff =
        "I cannot determine whether the structure is safe. Please wait for a certified engineer before entering."
    static let medicalHandoff =
        "I cannot diagnose medical conditions. Please consult trained medical personnel for injury assessment."

    static func detectContradiction(existing: Incident, newVictimCount: Int?) -> Contradiction? {
        guard let newVictimCount, newVictimCount != existing.victimCount else { return nil }
        return Contradiction(
            field: "victims",
            previous: "\(existing.victimCount)",
            latest: "\(newVictimCount)",
            incidentId: existing.id,
            incidentNumber: existing.number
        )
    }

    static func clarificationFields(uncertain: Bool) -> [String] {
        uncertain ? ["age", "conscious?", "trapped?", "injured?"] : []
    }
}
