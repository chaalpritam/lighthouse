import Foundation

enum DemoRunner {
    static let demoMissionName = "Chennai Earthquake Response"
    static let demoDisasterType = "Earthquake"
    static let demoLocation = "Chennai, Tamil Nadu"

    struct Step: Identifiable {
        let id = UUID()
        let userMessage: String
        let narration: String
        let delayAfter: Duration
    }

    static let steps: [Step] = [
        Step(
            userMessage: "Building C collapsed near T Nagar, 4 people trapped including 2 children",
            narration: "Reporting a critical incident — no network needed.",
            delayAfter: .seconds(5)
        ),
        Step(
            userMessage: "One unconscious victim at Building C, need ambulance urgently",
            narration: "Agent verifies and escalates priority locally.",
            delayAfter: .milliseconds(4500)
        ),
        Step(
            userMessage: "Actually 6 people trapped at Building C not 4",
            narration: "Contradiction detected — agent recovers and recalculates.",
            delayAfter: .milliseconds(4500)
        ),
        Step(
            userMessage: "Road to T Nagar blocked by debris",
            narration: "Accessibility update — plan reroutes resources.",
            delayAfter: .seconds(4)
        ),
        Step(
            userMessage: "Rescued one victim from Building C, Volunteer A",
            narration: "Rescue logged — next action suggested automatically.",
            delayAfter: .seconds(4)
        ),
        Step(
            userMessage: "What are the critical incidents?",
            narration: "Offline query — full mission state from local database.",
            delayAfter: .milliseconds(3500)
        )
    ]
}
