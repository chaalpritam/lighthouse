import SwiftUI

struct AgentsView: View {
    var viewModel: MissionViewModel
    @State private var description = ""
    @State private var detected: EmergencyAgent = .ambulance

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenScrollContent {
                    locationHeader
                    sosComposer
                    agentsList
                    if let sos = viewModel.lastSosDispatch {
                        lastSosSection(sos)
                    }
                }
            }
            .background(LighthouseBackground())
            .navigationTitle("Agents")
            .toolbarTitleDisplayMode(.large)
            .onChange(of: viewModel.voiceService.transcript) { _, text in
                if viewModel.voiceService.state != .listening, !text.isEmpty {
                    description = text
                    detected = EmergencyAgentClassifier.classify(text)
                }
            }
        }
    }

    private var locationHeader: some View {
        LocationCard(
            primary: viewModel.locationService.location?.shortLabel() ?? "Location unavailable",
            secondary: viewModel.locationService.location?.countryLabel() ?? "Unknown region"
        )
    }

    private var sosComposer: some View {
        SectionBlock(title: "Emergency") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("Describe the emergency")
                        .font(.headline)
                    TextField("Injured person near Building A…", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                        .lighthouseField()
                        .onChange(of: description) { _, value in
                            detected = EmergencyAgentClassifier.classify(value)
                        }

                    Label("Detected: \(detected.displayName)", systemImage: detected.systemImage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tint)

                    HStack(spacing: LHSpacing.sm) {
                        PrimaryButton(
                            title: "Auto SOS",
                            systemImage: "dot.radiowaves.left.and.right",
                            tint: LighthouseColor.critical
                        ) {
                            Task { await viewModel.dispatchSos(agent: nil, description: description) }
                        }

                        SecondaryButton(title: "Speak", systemImage: "mic.fill") {
                            viewModel.startListening()
                        }
                    }
                }
            }
        }
    }

    private var agentsList: some View {
        SectionBlock(title: "Dispatch Teams") {
            VStack(spacing: LHLayout.rowSpacing) {
                ForEach(EmergencyAgent.allCases) { agent in
                    agentCard(agent)
                }
            }
        }
    }

    private func agentCard(_ agent: EmergencyAgent) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: LHSpacing.sm) {
                IconWell(
                    systemName: agent.systemImage,
                    size: LHLayout.iconWellMd,
                    font: .title3
                )

                VStack(alignment: .leading, spacing: LHSpacing.xs) {
                    Text(agent.displayName)
                        .font(.headline)
                    Text(agent.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Available \(viewModel.availableCount(for: agent))  ·  Assigned \(viewModel.assignedCount(for: agent))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    PrimaryButton(
                        title: "SOS \(agent.displayName)",
                        tint: LighthouseColor.critical
                    ) {
                        Task { await viewModel.dispatchSos(agent: agent, description: description) }
                    }
                    .padding(.top, LHSpacing.xxs)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func lastSosSection(_ sos: SosDispatchResult) -> some View {
        SectionBlock(title: "Last SOS") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text(sos.message)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = URL(string: "tel://\(sos.emergencyNumber)") {
                        Link(destination: url) {
                            Label("Call \(sos.emergencyNumber)", systemImage: "phone.fill")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundStyle(LighthouseColor.critical)
                    }
                }
            }
        }
    }
}
