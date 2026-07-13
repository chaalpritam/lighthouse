import SwiftUI

struct AgentsView: View {
    var viewModel: MissionViewModel
    @State private var description = ""
    @State private var detected: EmergencyAgent = .ambulance

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LHLayout.sectionSpacing) {
                    locationHeader
                    sosComposer
                    agentsList
                    if let sos = viewModel.lastSosDispatch {
                        lastSosSection(sos)
                    }
                }
                .padding(.horizontal, LHLayout.screenPadding)
                .padding(.vertical, LHSpacing.md)
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
        SurfaceCard(padding: LHSpacing.sm) {
            HStack(spacing: LHSpacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.locationService.location?.shortLabel() ?? "Location unavailable")
                        .font(.body.weight(.semibold))
                    Text(viewModel.locationService.location?.countryLabel() ?? "Unknown region")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var sosComposer: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Emergency")
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.sm) {
                    Text("Describe the emergency")
                        .font(.headline)
                    TextField("Injured person near Building A…", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(LHSpacing.sm)
                        .background(
                            Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: LHLayout.controlCorner, style: .continuous)
                        )
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

                        Button {
                            viewModel.startListening()
                        } label: {
                            Label("Speak", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }
        }
    }

    private var agentsList: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Dispatch Teams")
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
                Image(systemName: agent.systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32, alignment: .center)
                    .padding(.top, 2)

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

                    Button("SOS \(agent.displayName)") {
                        Task { await viewModel.dispatchSos(agent: agent, description: description) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LighthouseColor.critical)
                    .controlSize(.regular)
                    .padding(.top, LHSpacing.xxs)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func lastSosSection(_ sos: SosDispatchResult) -> some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Last SOS")
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
