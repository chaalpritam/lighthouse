import SwiftUI

struct AgentsView: View {
    var viewModel: MissionViewModel
    @State private var description = ""
    @State private var detected: EmergencyAgent = .ambulance

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    locationHeader
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Describe the emergency")
                                .font(.headline)
                            TextField("Injured person near Building A…", text: $description, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: description) { _, value in
                                    detected = EmergencyAgentClassifier.classify(value)
                                }
                            Text("Detected: \(detected.displayName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LighthouseColor.blue)
                            HStack {
                                GlassPrimaryButton(title: "Auto SOS", systemImage: "dot.radiowaves.left.and.right", tint: LighthouseColor.critical) {
                                    Task { await viewModel.dispatchSos(agent: nil, description: description) }
                                }
                                Button {
                                    viewModel.startListening()
                                } label: {
                                    Label("Speak", systemImage: "mic.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }
                        }
                    }

                    ForEach(EmergencyAgent.allCases) { agent in
                        agentCard(agent)
                    }

                    if let sos = viewModel.lastSosDispatch {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeaderLabel(title: "Last SOS")
                                Text(sos.message)
                                    .font(.subheadline)
                                Link("Call \(sos.emergencyNumber)", destination: URL(string: "tel://\(sos.emergencyNumber)")!)
                                    .font(.headline)
                                    .foregroundStyle(LighthouseColor.critical)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(LighthouseBackground())
            .navigationTitle("Agents")
            .onChange(of: viewModel.voiceService.transcript) { _, text in
                if viewModel.voiceService.state != .listening, !text.isEmpty {
                    description = text
                    detected = EmergencyAgentClassifier.classify(text)
                }
            }
        }
    }

    private var locationHeader: some View {
        GlassCard(padding: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(LighthouseColor.blue)
                VStack(alignment: .leading) {
                    Text(viewModel.locationService.location?.shortLabel() ?? "Location unavailable")
                        .fontWeight(.semibold)
                    Text(viewModel.locationService.location?.countryLabel() ?? "Unknown region")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func agentCard(_ agent: EmergencyAgent) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: agent.systemImage)
                    .font(.title2)
                    .foregroundStyle(LighthouseColor.blue)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(agent.displayName).font(.headline)
                    Text(agent.summary).font(.caption).foregroundStyle(.secondary)
                    Text("Available \(viewModel.availableCount(for: agent)) · Assigned \(viewModel.assignedCount(for: agent))")
                        .font(.caption2.weight(.semibold))
                    Button("SOS \(agent.displayName)") {
                        Task { await viewModel.dispatchSos(agent: agent, description: description) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LighthouseColor.critical)
                    .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
