import SwiftUI

struct GuideConsoleView: View {
    var viewModel: MissionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(viewModel.mission?.name ?? "Mission")
                                .font(.title2.bold())
                            Text("\(viewModel.mission?.disasterType ?? "") · \(viewModel.mission?.location ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            viewModel.runDemo()
                        } label: {
                            Label(viewModel.isDemoRunning ? "Demo…" : "Play", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isDemoRunning)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderLabel(title: "Agent loop")
                            AgentLoopBar(current: viewModel.agentPhase, traversed: viewModel.phasesTraversed)
                            if let hint = viewModel.voiceHint {
                                Text(hint).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatTile(title: "Incidents", value: "\(viewModel.stats.incidents)")
                        StatTile(title: "Critical", value: "\(viewModel.stats.criticalIncidents)", tint: LighthouseColor.critical)
                        StatTile(title: "Awaiting", value: "\(viewModel.stats.awaitingRescue)", tint: LighthouseColor.high)
                        StatTile(title: "Rescued", value: "\(viewModel.stats.rescued)", tint: LighthouseColor.success)
                        StatTile(title: "Resources", value: "\(viewModel.stats.resources)")
                        StatTile(title: "Volunteers", value: "\(viewModel.stats.volunteers)")
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderLabel(title: "Agent briefing")
                            Text(viewModel.messages.last(where: { $0.role == "agent" })?.content
                                  ?? "Awaiting field reports.")
                        }
                    }

                    if !viewModel.planSteps.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeaderLabel(title: "Plan")
                                ForEach(Array(viewModel.planSteps.enumerated()), id: \.offset) { index, step in
                                    Text("\(index + 1). \(step.action)")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderLabel(title: "Incidents")
                        ForEach(viewModel.incidents, id: \.id) { incident in
                            GlassCard(padding: 12, cornerRadius: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("#\(incident.number) · \(incident.location)").fontWeight(.semibold)
                                        Text(incident.incidentDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                        Text("\(incident.victimCount) victims · \(incident.status)")
                                            .font(.caption2)
                                    }
                                    Spacer()
                                    PriorityBadge(priority: incident.priority)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderLabel(title: "Recent timeline")
                        ForEach(Array(viewModel.timeline.prefix(8)), id: \.id) { event in
                            HStack(alignment: .top) {
                                Text(event.createdAt, style: .time)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title).font(.subheadline.weight(.semibold))
                                    Text(event.eventDescription).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(LighthouseBackground())
            .navigationTitle("Guide")
        }
    }
}
