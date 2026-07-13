import SwiftUI

struct GuideConsoleView: View {
    var viewModel: MissionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LHLayout.sectionSpacing) {
                    missionHeader
                    agentLoopSection
                    statsSection
                    briefingSection
                    if !viewModel.planSteps.isEmpty {
                        planSection
                    }
                    incidentsSection
                    timelineSection
                }
                .padding(.horizontal, LHLayout.screenPadding)
                .padding(.vertical, LHSpacing.md)
            }
            .background(LighthouseBackground())
            .navigationTitle("Guide")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.runDemo()
                    } label: {
                        Label(viewModel.isDemoRunning ? "Running" : "Demo", systemImage: "play.fill")
                    }
                    .disabled(viewModel.isDemoRunning)
                }
            }
        }
    }

    private var missionHeader: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xxs) {
            Text(viewModel.mission?.name ?? "Mission")
                .font(.title2.weight(.bold))
            Text("\(viewModel.mission?.disasterType ?? "") · \(viewModel.mission?.location ?? "")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agentLoopSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Agent Loop")
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.xs) {
                    AgentLoopBar(current: viewModel.agentPhase, traversed: viewModel.phasesTraversed)
                    if let hint = viewModel.voiceHint {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Overview")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: LHLayout.rowSpacing), GridItem(.flexible(), spacing: LHLayout.rowSpacing)],
                spacing: LHLayout.rowSpacing
            ) {
                StatTile(title: "Incidents", value: "\(viewModel.stats.incidents)")
                StatTile(title: "Critical", value: "\(viewModel.stats.criticalIncidents)", tint: LighthouseColor.critical)
                StatTile(title: "Awaiting", value: "\(viewModel.stats.awaitingRescue)", tint: LighthouseColor.high)
                StatTile(title: "Rescued", value: "\(viewModel.stats.rescued)", tint: LighthouseColor.success)
                StatTile(title: "Resources", value: "\(viewModel.stats.resources)")
                StatTile(title: "Volunteers", value: "\(viewModel.stats.volunteers)")
            }
        }
    }

    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Agent Briefing")
            SurfaceCard {
                Text(viewModel.messages.last(where: { $0.role == "agent" })?.content
                      ?? "Awaiting field reports.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Plan")
            SurfaceCard {
                VStack(alignment: .leading, spacing: LHSpacing.xs) {
                    ForEach(Array(viewModel.planSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: LHSpacing.xs) {
                            Text("\(index + 1).")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            Text(step.action)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Incidents")
            if viewModel.incidents.isEmpty {
                SurfaceCard {
                    Text("No incidents logged yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: LHLayout.rowSpacing) {
                    ForEach(viewModel.incidents, id: \.id) { incident in
                        SurfaceCard(padding: LHSpacing.sm) {
                            HStack(alignment: .top, spacing: LHSpacing.sm) {
                                VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                                    Text("#\(incident.number) · \(incident.location)")
                                        .font(.body.weight(.semibold))
                                    Text(incident.incidentDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    Text("\(incident.victimCount) victims · \(incident.status)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: LHSpacing.xs)
                                PriorityBadge(priority: incident.priority)
                            }
                        }
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: LHSpacing.xs) {
            SectionHeaderLabel(title: "Recent Timeline")
            SurfaceCard {
                if viewModel.timeline.isEmpty {
                    Text("No timeline events yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: LHSpacing.sm) {
                        ForEach(Array(viewModel.timeline.prefix(8)), id: \.id) { event in
                            HStack(alignment: .top, spacing: LHSpacing.sm) {
                                Text(event.createdAt, style: .time)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(event.eventDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if event.id != viewModel.timeline.prefix(8).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}
