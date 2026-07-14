import SwiftUI

struct GuideConsoleView: View {
    var viewModel: MissionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenScrollContent {
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
        SurfaceCard(padding: LHSpacing.sm) {
            VStack(alignment: .leading, spacing: LHSpacing.xxs) {
                Text(viewModel.mission?.name ?? "Mission")
                    .font(.title3.weight(.bold))
                Text("\(viewModel.mission?.disasterType ?? "") · \(viewModel.mission?.location ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var agentLoopSection: some View {
        SectionBlock(title: "Agent Loop") {
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
        SectionBlock(title: "Overview") {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: LHLayout.rowSpacing),
                    GridItem(.flexible(), spacing: LHLayout.rowSpacing)
                ],
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
        SectionBlock(title: "Agent Briefing") {
            SurfaceCard {
                Text(viewModel.messages.last(where: { $0.role == "agent" })?.content
                      ?? "Awaiting field reports.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var planSection: some View {
        SectionBlock(title: "Plan") {
            SurfaceCard {
                PlanStepsList(steps: viewModel.planSteps)
            }
        }
    }

    private var incidentsSection: some View {
        SectionBlock(title: "Incidents") {
            if viewModel.incidents.isEmpty {
                EmptyStateCard(
                    title: "No Incidents",
                    description: "No incidents logged yet.",
                    compact: true
                )
            } else {
                VStack(spacing: LHLayout.rowSpacing) {
                    ForEach(viewModel.incidents, id: \.id) { incident in
                        IncidentRow(
                            incident: incident,
                            subtitle: "#\(incident.number) · \(incident.location)",
                            detail: incident.incidentDescription,
                            meta: "\(incident.victimCount) victims · \(incident.status)"
                        )
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        SectionBlock(title: "Recent Timeline") {
            SurfaceCard {
                if viewModel.timeline.isEmpty {
                    Text("No timeline events yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: LHSpacing.sm) {
                        ForEach(Array(viewModel.timeline.prefix(8)), id: \.id) { event in
                            TimelineEventRow(event: event)
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
