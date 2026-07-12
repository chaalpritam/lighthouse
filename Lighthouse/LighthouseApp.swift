import SwiftUI
import SwiftData

@main
struct LighthouseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Mission.self,
            Incident.self,
            Victim.self,
            Volunteer.self,
            ResourceUnit.self,
            TimelineEvent.self,
            MemoryEntry.self,
            ChatMessage.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
