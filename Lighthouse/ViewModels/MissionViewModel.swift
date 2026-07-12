import Foundation
import SwiftData
import SwiftUI
import UIKit

@Observable
@MainActor
final class MissionViewModel {
    var mission: Mission?
    var isLoading = true
    var isCreatingMission = false
    var isSending = false
    var isDemoRunning = false
    var demoStepIndex = 0
    var error: String?
    var voiceHint: String?
    var agentPhase: AgentLoopPhase = .idle
    var phasesTraversed: [AgentLoopPhase] = []
    var planSteps: [MissionPlanStep] = []
    var continuousVoiceMode = false
    var lastSosDispatch: SosDispatchResult?

    var incidents: [Incident] = []
    var timeline: [TimelineEvent] = []
    var messages: [ChatMessage] = []
    var resources: [ResourceUnit] = []
    var stats = MissionStats()

    let locationService: LocationService
    let voiceService: VoiceService
    let brainStatus: AgentBrainStatus
    private let repository: MissionRepository
    private let captureService = FieldCaptureService()
    private var demoTask: Task<Void, Never>?

    init(context: ModelContext, locationService: LocationService, voiceService: VoiceService, brainStatus: AgentBrainStatus) {
        self.repository = MissionRepository(context: context, locationService: locationService)
        self.locationService = locationService
        self.voiceService = voiceService
        self.brainStatus = brainStatus

        voiceService.onFinalTranscript = { [weak self] text in
            Task { @MainActor in
                await self?.sendMessage(text)
            }
        }
        voiceService.onSpeakDone = { [weak self] in
            Task { @MainActor in
                guard let self, self.continuousVoiceMode, !self.isDemoRunning, !self.isSending else { return }
                self.voiceService.startListening()
            }
        }
    }

    func loadMission() {
        isLoading = true
        do {
            mission = try repository.activeMission()
            refreshCollections()
            if mission != nil {
                locationService.startUpdates()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refreshCollections() {
        guard let missionId = mission?.id else {
            incidents = []; timeline = []; messages = []; resources = []; stats = MissionStats()
            return
        }
        do {
            incidents = try repository.fetchIncidents(missionId)
            timeline = try repository.fetchTimeline(missionId)
            messages = try repository.fetchMessages(missionId)
            resources = try repository.fetchResources(missionId)
            stats = try repository.stats(for: missionId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createMission(name: String, disasterType: String, location: String) async {
        isCreatingMission = true
        defer { isCreatingMission = false }
        do {
            let geo = locationService.location ?? await locationService.refreshOnce()
            locationService.startUpdates()
            let created = try repository.createMission(
                name: name,
                disasterType: disasterType,
                location: location,
                missionGeo: geo
            )
            mission = created
            refreshCollections()
            let whereLabel = geo?.shortLabel() ?? location
            voiceService.speak(
                "Lighthouse is ready. You're at \(whereLabel). Tap the microphone and tell me what's happening — I'll tell you what to do."
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func quickStart() async {
        let geo = locationService.location ?? await locationService.refreshOnce()
        let label = geo?.shortLabel() ?? "My area"
        await createMission(name: "Emergency — \(label)", disasterType: "Emergency", location: label)
    }

    func refreshLocation() async {
        _ = await locationService.refreshOnce()
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let missionId = mission?.id else { return }
        isSending = true
        agentPhase = .sense
        defer { isSending = false }
        do {
            let response = try await repository.processMessage(missionId: missionId, userMessage: trimmed)
            agentPhase = response.phase
            phasesTraversed = response.phasesTraversed
            planSteps = response.planSteps
            refreshCollections()
            voiceService.speak(response.message)
        } catch {
            self.error = error.localizedDescription
            agentPhase = .idle
        }
    }

    func dispatchSos(agent: EmergencyAgent?, description: String) async {
        guard let missionId = mission?.id else { return }
        isSending = true
        agentPhase = .sense
        defer { isSending = false }
        do {
            let result = try await repository.processSosDispatch(
                missionId: missionId,
                preferredAgent: agent,
                description: description
            )
            lastSosDispatch = result.sosResult
            agentPhase = result.agentResponse.phase
            phasesTraversed = result.agentResponse.phasesTraversed
            planSteps = result.agentResponse.planSteps
            refreshCollections()
            voiceService.speak(result.agentResponse.message)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startListening() { voiceService.startListening() }
    func stopListening() { voiceService.stopListening() }

    func testVoice() {
        voiceService.speak("Building A collapsed")
        voiceHint = "Voice test played"
    }

    func toggleContinuousVoice() {
        continuousVoiceMode.toggle()
        if continuousVoiceMode {
            startListening()
        } else {
            stopListening()
        }
    }

    func ingestPhoto(_ image: UIImage) async {
        guard let missionId = mission?.id else { return }
        do {
            let path = try captureService.savePhoto(image)
            let ocr = await captureService.recognizeText(in: image)
            _ = try await repository.ingestFieldCapture(missionId: missionId, photoPath: path, ocrText: ocr)
            refreshCollections()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func runDemo() {
        guard !isDemoRunning else { return }
        demoTask?.cancel()
        demoTask = Task {
            isDemoRunning = true
            defer { isDemoRunning = false; demoStepIndex = 0 }
            if mission == nil {
                await createMission(
                    name: DemoRunner.demoMissionName,
                    disasterType: DemoRunner.demoDisasterType,
                    location: DemoRunner.demoLocation
                )
            }
            for (index, step) in DemoRunner.steps.enumerated() {
                guard !Task.isCancelled else { return }
                demoStepIndex = index
                voiceHint = step.narration
                await sendMessage(step.userMessage)
                try? await Task.sleep(for: step.delayAfter)
            }
            voiceHint = "Demo complete"
        }
    }

    func exportMission() throws -> String {
        guard let missionId = mission?.id else { throw MissionSyncManager.SyncError.missionNotFound }
        return try repository.exportJSON(missionId: missionId)
    }

    func importMission(json: String) throws {
        let imported = try repository.importJSON(json)
        mission = imported
        refreshCollections()
    }

    func resetApp() throws {
        try repository.resetAll()
        mission = nil
        refreshCollections()
        agentPhase = .idle
        planSteps = []
        lastSosDispatch = nil
    }

    func availableCount(for agent: EmergencyAgent) -> Int {
        resources.filter { $0.type == agent.resourceType && $0.status == "available" }.count
    }

    func assignedCount(for agent: EmergencyAgent) -> Int {
        resources.filter { $0.type == agent.resourceType && $0.status == "assigned" }.count
    }
}
